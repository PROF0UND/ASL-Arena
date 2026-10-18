#!/usr/bin/env python3
"""Stand-in for the hand tracker. Sends packets in exactly the format ASL Arena expects.

The real tracker should send the same JSON, about 30 times a second, to UDP 127.0.0.1:4242:

    {
      "letter": "L",          # top guess among the game's letters, or null if a hand is visible but unrecognized
      "confidence": 0.92,     # 0..1 for that letter
      "scores": {"L": 0.92, "W": 0.02, ...},  # every game letter, adding up to 1 (optional but recommended)
      "hand_present": true,   # false when no hand is in frame
      "landmarks": [[x, y], ...]  # 21 MediaPipe hand landmarks, x/y normalized 0..1 (may be [])
    }

Usage:
    python3 tools/fake_sender.py                  # cycle through letters
    python3 tools/fake_sender.py --interactive    # type "A", "B 0.7", "?" (unrecognized), or "" (no hand)
"""
import argparse
import json
import math
import random
import socket
import threading
import time

LETTERS = list("LWIUKP")
SEND_HZ = 30


def fake_landmarks(t):
    """21 (x, y) points roughly shaped like an open hand, wobbling a little."""
    wrist = (0.5 + 0.02 * math.sin(t * 2.0), 0.85)
    points = [wrist]
    for angle in (-55, -22, -6, 10, 26):  # thumb, index, middle, ring, pinky
        direction = math.radians(angle - 90)
        for joint in range(4):
            r = 0.2 + 0.1 * joint
            points.append((wrist[0] + r * math.cos(direction), wrist[1] + r * math.sin(direction)))
    return [[round(x, 4), round(y, 4)] for x, y in points]


def make_packet(letter, confidence, hand_present, t):
    scores = {}
    if hand_present:
        others = [l for l in LETTERS if l != letter]
        rest = (1.0 - confidence) / len(others) if letter else 1.0 / len(LETTERS)
        scores = {l: round(rest, 3) for l in others}
        if letter:
            scores[letter] = round(confidence, 3)
    return {
        "letter": letter,
        "confidence": round(confidence, 3) if letter else 0.0,
        "scores": scores,
        "hand_present": hand_present,
        "landmarks": fake_landmarks(t) if hand_present else [],
    }


class State:
    def __init__(self):
        self.lock = threading.Lock()
        self.letter = None
        self.confidence = 0.0
        self.hand_present = False
        self.running = True

    def set(self, letter, confidence, hand_present):
        with self.lock:
            self.letter, self.confidence, self.hand_present = letter, confidence, hand_present

    def get(self):
        with self.lock:
            return self.letter, self.confidence, self.hand_present


def send_loop(sock, address, state):
    start = time.time()
    while state.running:
        letter, confidence, hand_present = state.get()
        packet = make_packet(letter, confidence, hand_present, time.time() - start)
        sock.sendto(json.dumps(packet).encode("utf-8"), address)
        time.sleep(1.0 / SEND_HZ)


def run_cycle(state, letters, hold, gap, min_conf):
    while True:
        for letter in letters:
            confidence = random.uniform(min_conf, 1.0)
            print(f"holding {letter}  (confidence {confidence:.2f})")
            state.set(letter, confidence, True)
            time.sleep(hold)
            state.set(None, 0.0, False)
            time.sleep(gap)


def run_interactive(state):
    print('Type a letter (optionally with confidence, e.g. "B 0.7"), "?" for an unrecognized hand,')
    print("or press Enter to take your hand away. Ctrl-D to quit.")
    while True:
        try:
            line = input("> ").strip().upper()
        except EOFError:
            return
        if not line:
            state.set(None, 0.0, False)
        elif line == "?":
            state.set(None, 0.0, True)
        else:
            parts = line.split()
            confidence = float(parts[1]) if len(parts) > 1 else 0.95
            state.set(parts[0][0], confidence, True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4242)
    parser.add_argument("--interactive", action="store_true")
    parser.add_argument("--letters", default="".join(LETTERS), help="letters to cycle through")
    parser.add_argument("--hold", type=float, default=1.0, help="seconds to hold each letter")
    parser.add_argument("--gap", type=float, default=0.3, help="seconds of no hand between letters")
    parser.add_argument("--min-conf", type=float, default=0.5, help="lowest random confidence")
    args = parser.parse_args()

    state = State()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    threading.Thread(target=send_loop, args=(sock, (args.host, args.port), state), daemon=True).start()
    print(f"Sending to {args.host}:{args.port}")
    try:
        if args.interactive:
            run_interactive(state)
        else:
            run_cycle(state, args.letters.upper(), args.hold, args.gap, args.min_conf)
    except KeyboardInterrupt:
        pass
    state.running = False


if __name__ == "__main__":
    main()
