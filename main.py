import logging
import sys
import time
from pathlib import Path

from src.clipper import Clipper
from src.config_loader import load_config
from src.detector import Detector
from src.recorder import Recorder


def setup_logging(log_dir: Path) -> None:
    log_dir.mkdir(exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(log_dir / "capture.log", encoding="utf-8"),
        ],
    )


def main() -> None:
    config = load_config()
    setup_logging(Path("logs"))
    logger = logging.getLogger(__name__)

    tmp_dir = Path(config["output"]["tmp_dir"])
    save_dir = Path(config["output"]["save_dir"])
    tmp_dir.mkdir(parents=True, exist_ok=True)
    save_dir.mkdir(parents=True, exist_ok=True)

    recorder = Recorder(
        rtsp_url=config["camera"]["rtsp_url"],
        rtsp_transport=config["camera"]["rtsp_transport"],
        segment_duration=config["recording"]["segment_duration"],
        tmp_dir=tmp_dir,
    )
    detector = Detector(
        model_path=config["detection"]["model"],
        confidence=config["detection"]["confidence_threshold"],
        interval_frames=config["detection"]["interval_frames"],
    )
    clipper = Clipper(
        save_dir=save_dir,
        min_clip_duration=config["clipping"]["min_clip_duration"],
    )

    recorder.start()
    logger.info("システム起動")

    # 処理状態の管理
    known_segments: list[Path] = []   # 検出済みの完了セグメント（時刻順）
    detection_results: dict[Path, bool] = {}
    finalize_idx: int = 0             # 次にクリッピング判定するセグメントのインデックス
    delete_idx: int = 0               # 次に削除候補とするセグメントのインデックス
    buffer_size: int = config["recording"]["buffer_segments"]

    try:
        while recorder.is_running():
            # 録画中の最後のファイルを除いた完了済みセグメントを取得
            all_segs = sorted(tmp_dir.glob("*.mp4"))
            complete = all_segs[:-1] if len(all_segs) > 1 else []

            # 新規セグメントを人物検出して登録
            known_set = set(known_segments)
            for seg in complete:
                if seg not in known_set:
                    has_person = detector.detect(seg)
                    detection_results[seg] = has_person
                    known_segments.append(seg)
                    logger.info(f"{seg.name}: {'人物検出' if has_person else '人物なし'}")

            # ポストバッファが揃ったセグメントのクリッピング判定
            # セグメントN の判定は N+1 が完了してから行う
            while finalize_idx < len(known_segments) - 1:
                i = finalize_idx
                curr = known_segments[i]
                pre = known_segments[i - 1] if i > 0 else None
                post = known_segments[i + 1]

                if detection_results.get(curr):
                    segs = [s for s in [pre, curr, post] if s is not None]
                    clipper.save(segs)

                finalize_idx += 1

            # バッファウィンドウ外の古いセグメントを削除
            delete_threshold = finalize_idx - buffer_size
            while delete_idx < delete_threshold:
                seg = known_segments[delete_idx]
                if seg.exists():
                    seg.unlink()
                    logger.debug(f"セグメント削除: {seg.name}")
                detection_results.pop(seg, None)
                delete_idx += 1

            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("停止シグナル受信 (Ctrl+C)")
    finally:
        recorder.stop()
        logger.info("システム終了")


if __name__ == "__main__":
    main()
