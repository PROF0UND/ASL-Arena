import cv2
from cvzone.HandTrackingModule import HandDetector
import numpy as np
import math
import time

cap = cv2.VideoCapture(0)
detector = HandDetector(maxHands=1)

offset = 20
imgSize = 500
folder = "image_data_processed"
counter = 0

# MediaPipe 21-landmark bone connection pairs
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

    # 1. Mirror horizontally
    img = cv2.flip(img, 1)

    # 2. draw=False eliminates the green center circle and default overlays
    hands, img = detector.findHands(img, draw=False, flipType=False)

    if hands:
        hand = hands[0]
        x, y, w, h = hand['bbox']
        lmList = hand['lmList']  # 21 landmarks: [[x, y, z], ...]
        hand_type = hand['type']

        # 3. Resolve "Unknown" label using landmark geometry on mirrored frame
        if hand_type == "Unknown" or not hand_type:
            # On a mirrored feed facing the camera:
            # Right hand: Thumb (lm 4) is to the left of Pinky (lm 20)
            # Left hand:  Thumb (lm 4) is to the right of Pinky (lm 20)
            if lmList[4][0] < lmList[20][0]:
                hand_type = "Right"
            else:
                hand_type = "Left"

        # 4. Draw bone lines (green)
        for p1, p2 in CONNECTIONS:
            pt1 = (lmList[p1][0], lmList[p1][1])
            pt2 = (lmList[p2][0], lmList[p2][1])
            cv2.line(img, pt1, pt2, (0, 255, 0), 2)

        # 5. Draw joint points (red)
        for lm in lmList:
            cv2.circle(img, (lm[0], lm[1]), 4, (0, 0, 255), cv2.FILLED)

        # 6. Draw clean bounding box and resolved label
        cv2.rectangle(img, (x - offset, y - offset), (x + w + offset, y + h + offset), (255, 0, 255), 2)
        cv2.putText(img, hand_type, (x, y - offset - 10), cv2.FONT_HERSHEY_PLAIN, 2, (255, 0, 255), 2)

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

                cv2.imshow("ImageCrop", imgCrop)
                cv2.imshow("ImageBlank", imgBlank)

            except Exception:
                continue

    cv2.imshow("Image", img)

    key = cv2.waitKey(1)
    if key == ord("s"):
        counter += 1
        cv2.imwrite(f'{folder}/Image_{time.time()}.jpg', imgBlank)
        print(f"saved image count: {counter}")
    elif key == ord("q"):
        break

cap.release()
cv2.destroyAllWindows()
