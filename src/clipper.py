import logging
import subprocess
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)


class Clipper:
    def __init__(self, save_dir: Path, min_clip_duration: int, pre_buffer: int, post_buffer: int, segment_duration: int):
        self.save_dir = save_dir
        self.min_clip_duration = min_clip_duration
        self.pre_buffer = pre_buffer
        self.post_buffer = post_buffer
        self.segment_duration = segment_duration

    def save(self, segments: list[Path], n_pre: int = 0, n_post: int = 0) -> Path | None:
        """複数のセグメントを結合し、前後バッファをトリミングして保存する。

        Args:
            segments: 結合するセグメントファイルのリスト
            n_pre: リスト先頭に含まれるプリバッファセグメント数
            n_post: リスト末尾に含まれるポストバッファセグメント数
        """
        existing = [s for s in segments if s.exists()]
        if not existing:
            logger.warning("保存対象のセグメントが存在しません")
            return None

        self.save_dir.mkdir(parents=True, exist_ok=True)

        concat_file = self.save_dir / "_concat_tmp.txt"
        concat_file.write_text("\n".join(f"file '{s}'" for s in existing))

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_path = self.save_dir / f"{timestamp}.mp4"

        # プリバッファのトリム: プリセグメント分 - pre_buffer秒 をスキップ
        ss = max(0, n_pre * self.segment_duration - self.pre_buffer)
        # ポストバッファのトリム: 全体長 - (ポストセグメント分 - post_buffer秒) で打ち切り
        total_duration = len(existing) * self.segment_duration
        to = total_duration - max(0, n_post * self.segment_duration - self.post_buffer)

        cmd = [
            "ffmpeg",
            "-f", "concat",
            "-safe", "0",
            "-i", str(concat_file),
            "-ss", str(ss),
            "-to", str(to),
            "-an",
            "-c:v", "copy",
            "-loglevel", "warning",
            str(output_path),
        ]

        try:
            result = subprocess.run(cmd, capture_output=True, timeout=120)
            if result.returncode != 0:
                logger.error(f"クリップ保存失敗: {result.stderr.decode()}")
                return None
            logger.info(f"クリップ保存: {output_path.name} (ss={ss}s, to={to}s)")
            return output_path
        except subprocess.TimeoutExpired:
            logger.error("クリップ保存タイムアウト")
            return None
        finally:
            concat_file.unlink(missing_ok=True)
