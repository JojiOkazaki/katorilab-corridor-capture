import logging
from pathlib import Path

import cv2
from ultralytics import YOLO

logger = logging.getLogger(__name__)


class Detector:
    def __init__(self, model_path: str, confidence: float, interval_frames: int):
        logger.info(f"YOLOモデル読み込み: {model_path}")
        self.model = YOLO(model_path)
        self.confidence = confidence
        self.interval_frames = interval_frames

    def detect(self, video_path: Path) -> bool:
        """動画ファイルを解析し、人物が検出されたかどうかを返す。"""
        cap = cv2.VideoCapture(str(video_path))
        if not cap.isOpened():
            logger.warning(f"動画ファイルを開けません: {video_path}")
            return False

        frame_idx = 0
        detected = False

        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    break

                if frame_idx % self.interval_frames == 0:
                    results = self.model(
                        frame,
                        classes=[0],  # YOLOクラス0 = person
                        conf=self.confidence,
                        verbose=False,
                    )
                    if any(len(r.boxes) > 0 for r in results):
                        detected = True
                        break

                frame_idx += 1
        finally:
            cap.release()

        return detected
