import logging
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)


class Recorder:
    def __init__(
        self,
        rtsp_url: str,
        rtsp_transport: str,
        segment_duration: int,
        tmp_dir: Path,
    ):
        self.rtsp_url = rtsp_url
        self.rtsp_transport = rtsp_transport
        self.segment_duration = segment_duration
        self.tmp_dir = tmp_dir
        self._process: subprocess.Popen | None = None

    def start(self) -> None:
        self.tmp_dir.mkdir(parents=True, exist_ok=True)
        segment_pattern = str(self.tmp_dir / "%Y%m%d_%H%M%S.mp4")

        cmd = [
            "ffmpeg",
            "-rtsp_transport", self.rtsp_transport,
            "-i", self.rtsp_url,
            "-an",
            "-c:v", "copy",
            "-f", "segment",
            "-segment_time", str(self.segment_duration),
            "-segment_format", "mp4",
            "-strftime", "1",
            "-reset_timestamps", "1",
            "-loglevel", "warning",
            segment_pattern,
        ]

        logger.info("FFmpeg録画開始")
        self._process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )

    def stop(self) -> None:
        if self._process is not None:
            self._process.terminate()
            try:
                self._process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self._process.kill()
            logger.info("FFmpeg録画停止")

    def is_running(self) -> bool:
        return self._process is not None and self._process.poll() is None
