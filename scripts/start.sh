#!/bin/bash
# main.pyをバックグラウンドで起動するスクリプト
# Windowsタスクスケジューラから呼び出す

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
LOG_FILE="$PROJECT_DIR/logs/capture.log"
PID_FILE="$PROJECT_DIR/logs/main.pid"

# ログディレクトリ作成
mkdir -p "$PROJECT_DIR/logs"

# すでに起動中なら何もしない
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "すでに起動中です (PID: $(cat "$PID_FILE"))"
    exit 0
fi

# conda activateを使わずフルパスで指定（非インタラクティブシェル対応）
PYTHON="$HOME/miniconda3/envs/katorilab-corridor-capture/bin/python"

# nohup + setsidでWSLセッションから完全に切り離して起動
nohup setsid bash "$SCRIPT_DIR/loop.sh" "$PYTHON" "$LOG_FILE" "$PID_FILE" "$PROJECT_DIR" > /dev/null 2>&1 &

LOOP_PID=$!
echo $LOOP_PID > "$PID_FILE"
echo "起動完了 (PID: $LOOP_PID)"
