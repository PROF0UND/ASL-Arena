#!/usr/bin/env python3
"""ASL Arena hand tracker: webcam -> hand crop -> Teachable Machine model -> UDP packets for the game.

Sends JSON to 127.0.0.1:4242 about 30 times a second (the format is in ../README.md):
    {"letter": "L", "confidence": 0.91, "hand_present": true, "landmarks": [[x, y], ...]}

The game does the hold-to-confirm; this script just reports what it sees each frame.

Usage (from this folder, inside the Python 3.12 venv):
    python tracker.py                    # preview window, the letters the game uses
    python tracker.py --no-preview       # no OpenCV window
    python tracker.py --letters LWKPUI  # only ever report these letters
    python tracker.py --mirror-input     # classify the mirrored image (try this if accuracy is poor)
"""
import argparse
import json
import math
import os
import socket
import time
from collections import deque

os.environ["TF_USE_LEGACY_KERAS"] = "1"  # Teachable Machine models need legacy Keras 2
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")  # hide TensorFlow's startup log spam
os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")  # CPU is plenty for this model; skip the GPU probe

import cv2  # noqa: E402
import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402
import tf_keras as keras  # noqa: E402
from cvzone.HandTrackingModule import HandDetector  # noqa: E402

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "Model", "keras_model.h5")
LABELS_PATH = os.path.join(BASE_DIR, "Model", "labels.txt")

# Must match preprocess_kaggle.py / hand_detection.py, or the model sees different images than it trained on.
OFFSET = 20
CANVAS_SIZE = 500
MODEL_SIZE = 224
CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),        # Thumb
    (0, 5), (5, 6), (6, 7), (7, 8),        # Index
    (5, 9), (9, 10), (10, 11), (11, 12),   # Middle
    (9, 13), (13, 14), (14, 15), (15, 16), # Ring
    (13, 17), (17, 18), (18, 19), (19, 20),# Pinky
    (0, 17),                               # Palm base
]


def load_labels(path):
    with open(path) as f:
        return [line.strip().split(" ")[-1] for line in f if line.strip()]


def draw_skeleton(img, lm_list):
    """The same green bones and red joints the training images were drawn with."""
    for a, b in CONNECTIONS:
        cv2.line(img, tuple(lm_list[a][:2]), tuple(lm_list[b][:2]), (0, 255, 0), 2)
    for lm in lm_list:
        cv2.circle(img, tuple(lm[:2]), 4, (0, 0, 255), cv2.FILLED)


def hand_canvas(img, bbox):
    """Crop the hand and center it on a white square, exactly like the training data. None if it can't."""
    x, y, w, h = bbox
    img_h, img_w = img.shape[:2]
    crop = img[max(0, y - OFFSET):min(img_h, y + h + OFFSET), max(0, x - OFFSET):min(img_w, x + w + OFFSET)]
    if crop.size == 0 or w == 0 or h == 0:
        return None
    canvas = np.full((CANVAS_SIZE, CANVAS_SIZE, 3), 255, np.uint8)
    try:
        if h / w > 1:
            new_w = math.ceil(CANVAS_SIZE / h * w)
            gap = math.ceil((CANVAS_SIZE - new_w) / 2)
            canvas[:, gap:gap + new_w] = cv2.resize(crop, (new_w, CANVAS_SIZE))
        else:
            new_h = math.ceil(CANVAS_SIZE / w * h)
            gap = math.ceil((CANVAS_SIZE - new_h) / 2)
            canvas[gap:gap + new_h, :] = cv2.resize(crop, (CANVAS_SIZE, new_h))
    except ValueError:  # rounding pushed the hand one pixel past the canvas
        return None
    return canvas


def to_tensor(canvas):
    """Teachable Machine input: 224x224 RGB scaled to [-1, 1]."""
    rgb = cv2.cvtColor(cv2.resize(canvas, (MODEL_SIZE, MODEL_SIZE)), cv2.COLOR_BGR2RGB)
    return rgb.astype(np.float32)[None] / 127.5 - 1.0


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4242)
    parser.add_argument("--camera", type=int, default=0, help="webcam index")
    parser.add_argument("--letters", default="LWKPUI", help='letters to report, or "all"')
    parser.add_argument("--smooth", type=int, default=5, help="average predictions over this many frames")
    parser.add_argument("--mirror-input", action="store_true", help="classify the mirrored camera image")
    parser.add_argument("--no-preview", action="store_true", help="don't open an OpenCV window")
    return parser.parse_args()


def main():
    args = parse_args()
    labels = load_labels(LABELS_PATH)
    if args.letters.lower() == "all":
        allowed = list(range(len(labels)))
    else:
        wanted = set(args.letters.upper())
        allowed = [i for i, label in enumerate(labels) if label in wanted]
        missing = wanted - {labels[i] for i in allowed}
        if missing:
            print(f"warning: the model has no class for {''.join(sorted(missing))}")
    print(f"Loading model ({len(labels)} classes), reporting: {''.join(labels[i] for i in allowed)}")
    model = keras.models.load_model(MODEL_PATH, compile=False)
    # Compiled once, about 10x faster per frame than calling the model directly (~5 ms vs ~60 ms on a laptop CPU).
    predict = tf.function(lambda batch: model(batch, training=False), reduce_retracing=True)

    detector = HandDetector(maxHands=1)
    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        raise SystemExit(f"Could not open camera {args.camera}. Try --camera 1.")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    address = (args.host, args.port)
    history = deque(maxlen=max(1, args.smooth))
    print(f"Sending to {address[0]}:{address[1]}. Press q in the preview window (or Ctrl-C) to quit.")

    fps, frames, fps_clock = 0.0, 0, time.time()
    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                print("camera read failed")
                time.sleep(0.1)
                continue
            # The Kaggle training images aren't mirrored, so classify the raw frame by default
            # and mirror only what the player sees.
            if args.mirror_input:
                frame = cv2.flip(frame, 1)
            frame_h, frame_w = frame.shape[:2]
            hands, _ = detector.findHands(frame, draw=False, flipType=False)

            packet = {"letter": None, "confidence": 0.0, "hand_present": False, "landmarks": []}
            canvas = None
            if hands:
                hand = hands[0]
                lm_list = hand["lmList"]
                drawn = frame.copy()
                draw_skeleton(drawn, lm_list)  # training crops had the skeleton drawn on them
                canvas = hand_canvas(drawn, hand["bbox"])
                packet["hand_present"] = True
                # Landmarks in the player's (mirrored) view, normalized 0..1, for the game's hand panel.
                packet["landmarks"] = [
                    [round(p[0] / frame_w if args.mirror_input else 1 - p[0] / frame_w, 4), round(p[1] / frame_h, 4)]
                    for p in lm_list
                ]
                if canvas is not None:
                    history.append(predict(to_tensor(canvas)).numpy()[0])
                    probs = np.mean(history, axis=0)
                    best = max(allowed, key=lambda i: probs[i])
                    packet["letter"] = labels[best]
                    packet["confidence"] = round(float(probs[best]), 3)
            else:
                history.clear()
            sock.sendto(json.dumps(packet).encode("utf-8"), address)

            frames += 1
            if time.time() - fps_clock >= 1.0:
                fps, frames, fps_clock = frames / (time.time() - fps_clock), 0, time.time()

            if not args.no_preview:
                view = frame.copy()
                if hands:
                    draw_skeleton(view, hands[0]["lmList"])
                if not args.mirror_input:
                    view = cv2.flip(view, 1)
                status = f"{packet['letter'] or '-'}  {packet['confidence']:.2f}   {fps:.0f} fps"
                cv2.putText(view, status, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (255, 0, 255), 2)
                cv2.imshow("ASL Arena tracker", view)
                if canvas is not None:
                    cv2.imshow("Model input", cv2.resize(canvas, (MODEL_SIZE, MODEL_SIZE)))
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
