import logging
import subprocess
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)


class Clipper:
    def __init__(self, save_dir: Path, min_clip_duration: int):
        self.save_dir = save_dir
        self.min_clip_duration = min_clip_duration

    def save(self, segments: list[Path]) -> Path | None:
        """複数のセグメントを結合してクリップとして保存する。"""
        existing = [s for s in segments if s.exists()]
        if not existing:
            logger.warning("保存対象のセグメントが存在しません")
            return None

        self.save_dir.mkdir(parents=True, exist_ok=True)

        concat_file = self.save_dir / "_concat_tmp.txt"
        concat_file.write_text("\n".join(f"file '{s}'" for s in existing))

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = self.save_dir / f"{timestamp}.mp4"

        cmd = [
            "ffmpeg",
            "-f", "concat",
            "-safe", "0",
            "-i", str(concat_file),
            "-c", "copy",
            "-loglevel", "warning",
            str(output_path),
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, timeout=60)
            if result.returncode != 0:
                logger.error(f"クリップ保存失敗: {result.stderr.decode()}")
                return None
            logger.info(f"クリップ保存: {output_path.name}")
            return output_path
        except subprocess.TimeoutExpired:
            logger.error("クリップ保存タイムアウト")
            return None
        finally:
            concat_file.unlink(missing_ok=True)
