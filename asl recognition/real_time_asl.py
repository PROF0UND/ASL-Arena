import os
# Force TensorFlow to use legacy Keras 2 to support Teachable Machine models
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import cv2
from cvzone.HandTrackingModule import HandDetector
import numpy as np
import math
import tf_keras as keras

# 1. Load the model directly using legacy tf_keras
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
model_path = os.path.join(BASE_DIR, "Model", "keras_model.h5")
labels_path = os.path.join(BASE_DIR, "Model", "labels.txt")

model = keras.models.load_model(model_path, compile=False)

# Read labels dynamically
with open(labels_path, "r") as f:
    labels = [line.strip().split(" ")[-1] for line in f.readlines() if line.strip()]

cap = cv2.VideoCapture(0)
detector = HandDetector(maxHands=1)

offset = 20
imgSize = 500

CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),           # Thumb
    (0, 5), (5, 6), (6, 7), (7, 8),           # Index
    (5, 9), (9, 10), (10, 11), (11, 12),      # Middle
    (9, 13), (13, 14), (14, 15), (15, 16),    # Ring
    (13, 17), (17, 18), (18, 19), (19, 20),   # Pinky
    (0, 17)                                   # Palm base
]

while True:
    success, img = cap.read()
    if not success:
        break

    # Mirror horizontally
    img = cv2.flip(img, 1)
    imgOutput = img.copy()

    # Hand detection without default cvzone drawings
    hands, img = detector.findHands(img, draw=False, flipType=False)

    if hands:
        hand = hands[0]
        x, y, w, h = hand['bbox']
        lmList = hand['lmList']

        # Draw hand skeleton onto output display
        for p1, p2 in CONNECTIONS:
            pt1 = (lmList[p1][0], lmList[p1][1])
            pt2 = (lmList[p2][0], lmList[p2][1])
            cv2.line(imgOutput, pt1, pt2, (0, 255, 0), 2)

        for lm in lmList:
            cv2.circle(imgOutput, (lm[0], lm[1]), 4, (0, 0, 255), cv2.FILLED)

        # Boundary clamping to prevent empty crops near frame edges
        img_h, img_w, _ = img.shape
        y1 = max(0, y - offset)
        y2 = min(img_h, y + h + offset)
        x1 = max(0, x - offset)
        x2 = min(img_w, x + w + offset)

        imgCrop = img[y1:y2, x1:x2]

        if imgCrop.size != 0 and imgCrop.shape[0] != 0 and imgCrop.shape[1] != 0:
            try:
                imgBlank = np.ones((imgSize, imgSize, 3), np.uint8) * 255
                aspectRatio = h / w

                if aspectRatio > 1:
                    const_val = imgSize / h
                    calculatedWidth = math.ceil(const_val * w)
                    imgResize = cv2.resize(imgCrop, (calculatedWidth, imgSize))
                    widthGap = math.ceil((imgSize - calculatedWidth) / 2)
                    imgBlank[:, widthGap:calculatedWidth + widthGap] = imgResize
                else:
                    const_val = imgSize / w
                    calculatedHeight = math.ceil(const_val * h)
                    imgResize = cv2.resize(imgCrop, (imgSize, calculatedHeight))
                    heightGap = math.ceil((imgSize - calculatedHeight) / 2)
                    imgBlank[heightGap:calculatedHeight + heightGap, :] = imgResize

                # Preprocess imgBlank for Teachable Machine (expects 224x224 RGB, normalized to [-1, 1])
                input_img = cv2.resize(imgBlank, (224, 224))
                input_img = cv2.cvtColor(input_img, cv2.COLOR_BGR2RGB)
                input_tensor = np.asarray(input_img, dtype=np.float32).reshape(1, 224, 224, 3)
                input_tensor = (input_tensor / 127.5) - 1.0

                # Predict
                predictions = model.predict(input_tensor, verbose=0)
                index = int(np.argmax(predictions))
                predicted_letter = labels[index]

                # Draw bounding box and prediction badge
                cv2.rectangle(imgOutput, (x - offset, y - offset),
                              (x + w + offset, y + h + offset), (255, 0, 255), 3)

                cv2.rectangle(imgOutput, (x - offset, y - offset - 45),
                              (x - offset + 80, y - offset), (255, 0, 255), cv2.FILLED)

                cv2.putText(imgOutput, predicted_letter, (x - offset + 25, y - offset - 10),
                            cv2.FONT_HERSHEY_COMPLEX, 1.2, (255, 255, 255), 2)

                cv2.imshow("Normalized Feed", imgBlank)

            except Exception:
                continue

    cv2.imshow("ASL Real-Time Recognition", imgOutput)

    if cv2.waitKey(1) == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
