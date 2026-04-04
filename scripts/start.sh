#!/bin/bash
# main.pyをバックグラウンドで起動するスクリプト
# Windowsタスクスケジューラから呼び出す

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
LOG_FILE="$PROJECT_DIR/logs/capture.log"
PID_FILE="$PROJECT_DIR/logs/main.pid"

# すでに起動中なら何もしない
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "すでに起動中です (PID: $(cat "$PID_FILE"))"
    exit 0
fi

source "$HOME/miniconda3/etc/profile.d/conda.sh"
conda activate katorilab-corridor-capture

cd "$PROJECT_DIR"
nohup python main.py >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "起動完了 (PID: $!)"
