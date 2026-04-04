#!/bin/bash
# 再起動ループスクリプト（start.shからnohup setsidで呼び出される）

PYTHON="$1"
LOG_FILE="$2"
PID_FILE="$3"
PROJECT_DIR="$4"

PYTHON_PID=""

trap '
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 停止シグナル受信" >> "$LOG_FILE"
    [ -n "$PYTHON_PID" ] && kill "$PYTHON_PID" 2>/dev/null
    rm -f "$PID_FILE"
    exit 0
' SIGTERM SIGINT

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] main.py 起動" >> "$LOG_FILE"
    cd "$PROJECT_DIR"
    "$PYTHON" main.py >> "$LOG_FILE" 2>&1 &
    PYTHON_PID=$!
    wait $PYTHON_PID
    EXIT_CODE=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 終了 (exit=${EXIT_CODE}) - 30秒後に再起動します" >> "$LOG_FILE"
    sleep 30
done
