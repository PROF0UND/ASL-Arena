import os
import cv2
import numpy as np
import math
from cvzone.HandTrackingModule import HandDetector

detector = HandDetector(maxHands=1)
imgSize = 500
offset = 20

# Path to unzipped Kaggle dataset folders and output destination
raw_data_dir = "asl_alphabet_train"  # Folder containing A, B, C subdirectories
processed_data_dir = "image_data_processed"

CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (0, 5), (5, 6), (6, 7), (7, 8),
    (5, 9), (9, 10), (10, 11), (11, 12),
    (9, 13), (13, 14), (14, 15), (15, 16),
    (13, 17), (17, 18), (18, 19), (19, 20),
    (0, 17)
]

for label in os.listdir(raw_data_dir):
    src_folder = os.path.join(raw_data_dir, label)
    if not os.path.isdir(src_folder):
        continue

    dst_folder = os.path.join(processed_data_dir, label)
    os.makedirs(dst_folder, exist_ok=True)

    # Process ~200-300 images per letter
    for img_name in os.listdir(src_folder)[:300]:
        img_path = os.path.join(src_folder, img_name)
        img = cv2.imread(img_path)
        if img is None:
            continue

        hands, img = detector.findHands(img, draw=False, flipType=False)
        if not hands:
            continue

        hand = hands[0]
        x, y, w, h = hand['bbox']
        lmList = hand['lmList']

        # 1. Draw matching skeleton on the image
        for p1, p2 in CONNECTIONS:
            cv2.line(img, (lmList[p1][0], lmList[p1][1]), (lmList[p2][0], lmList[p2][1]), (0, 255, 0), 2)
        for lm in lmList:
            cv2.circle(img, (lm[0], lm[1]), 4, (0, 0, 255), cv2.FILLED)

        # 2. Crop with boundaries clamped
        h_img, w_img, _ = img.shape
        y1, y2 = max(0, y - offset), min(h_img, y + h + offset)
        x1, x2 = max(0, x - offset), min(w_img, x + w + offset)
        imgCrop = img[y1:y2, x1:x2]

        if imgCrop.size == 0 or w == 0 or h == 0:
            continue

        # 3. Place on uniform white canvas
        imgBlank = np.ones((imgSize, imgSize, 3), np.uint8) * 255
        aspectRatio = h / w

        try:
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

            cv2.imwrite(os.path.join(dst_folder, img_name), imgBlank)
        except Exception:
            continue

print("Preprocessing complete! Upload the processed folders to Teachable Machine.")
