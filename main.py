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


def save_window(
    clipper: Clipper,
    known_segments: list[Path],
    window_start: int,
    window_end: int,
    logger: logging.Logger,
) -> None:
    """検出ウィンドウ[window_start, window_end]を前後バッファを含めて保存する。"""
    pre_idx = max(0, window_start - 1)
    post_idx = min(len(known_segments) - 1, window_end + 1)
    n_pre = window_start - pre_idx    # 0 or 1
    n_post = post_idx - window_end    # 0 or 1
    segs = known_segments[pre_idx : post_idx + 1]
    logger.info(
        f"クリップ確定: {known_segments[window_start].name}"
        f" 〜 {known_segments[window_end].name} ({len(segs)}セグメント)"
    )
    clipper.save(segs, n_pre=n_pre, n_post=n_post)


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
        pre_buffer=config["clipping"]["pre_buffer"],
        post_buffer=config["clipping"]["post_buffer"],
        segment_duration=config["recording"]["segment_duration"],
    )

    recorder.start()
    logger.info("システム起動")

    known_segments: list[Path] = []
    detection_results: dict[Path, bool] = {}
    confidence_results: dict[Path, float] = {}
    finalize_idx: int = 0
    delete_idx: int = 0
    buffer_size: int = config["recording"]["buffer_segments"]

    # 検出ウィンドウ: 連続検出の開始・終了インデックス
    window_start: int | None = None
    window_end: int | None = None

    try:
        while recorder.is_running():
            # 録画中の最後のファイルを除いた完了済みセグメントを取得
            all_segs = sorted(tmp_dir.glob("*.mp4"))
            complete = all_segs[:-1] if len(all_segs) > 1 else []

            # 新規セグメントを人物検出して登録
            known_set = set(known_segments)
            for seg in complete:
                if seg not in known_set:
                    has_person, max_conf = detector.detect(seg)
                    detection_results[seg] = has_person
                    confidence_results[seg] = max_conf
                    known_segments.append(seg)
                    if has_person:
                        logger.info(f"{seg.name}: 人物検出 (conf={max_conf:.2f})")
                    else:
                        logger.info(f"{seg.name}: 人物なし (max_conf={max_conf:.2f})")

            # 連続検出ウィンドウを管理してクリッピング判定
            # セグメントN の判定は N+1 が完了してから行う（ポストバッファのため）
            while finalize_idx < len(known_segments) - 1:
                i = finalize_idx
                curr = known_segments[i]

                if detection_results.get(curr):
                    # 人物あり: ウィンドウを開始 or 継続
                    if window_start is None:
                        window_start = i
                    window_end = i
                else:
                    # 人物なし: 直前までウィンドウが開いていたら確定して保存
                    if window_start is not None:
                        save_window(clipper, known_segments, window_start, window_end, logger)
                        window_start = None
                        window_end = None

                finalize_idx += 1

            # バッファウィンドウ外かつ検出ウィンドウ外の古いセグメントを削除
            safe_delete = finalize_idx - buffer_size
            if window_start is not None:
                # 検出ウィンドウのプリバッファは削除しない
                safe_delete = min(safe_delete, window_start - 1)

            while delete_idx < safe_delete:
                seg = known_segments[delete_idx]
                if seg.exists():
                    seg.unlink()
                    logger.debug(f"セグメント削除: {seg.name}")
                detection_results.pop(seg, None)
                confidence_results.pop(seg, None)
                delete_idx += 1

            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("停止シグナル受信 (Ctrl+C)")
    finally:
        # 終了時に未確定の検出ウィンドウがあれば保存
        if window_start is not None:
            logger.info("終了時に未確定のウィンドウを保存")
            save_window(clipper, known_segments, window_start, window_end, logger)
        recorder.stop()
        logger.info("システム終了")


if __name__ == "__main__":
    main()
