#!/bin/bash
# タスクスケジューラ専用起動スクリプト（ブロッキング実行）
# このスクリプト自体がプロセスとして動き続け、stop.shで停止できる

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
LOG_FILE="$PROJECT_DIR/logs/capture.log"
PID_FILE="$PROJECT_DIR/logs/main.pid"
PYTHON="$HOME/miniconda3/envs/katorilab-corridor-capture/bin/python"

mkdir -p "$PROJECT_DIR/logs"

# 既存プロセスが動いていれば何もしない
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    exit 0
fi

# このスクリプト自体のPIDを記録（stop.shで停止できるようにする）
echo $$ > "$PID_FILE"
cd "$PROJECT_DIR"

PYTHON_PID=""

trap '
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] 停止シグナル受信" >> "$LOG_FILE"
    [ -n "$PYTHON_PID" ] && kill "$PYTHON_PID" 2>/dev/null
    rm -f "$PID_FILE"
    exit 0
' SIGTERM SIGINT

# 再起動ループ
while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] main.py 起動" >> "$LOG_FILE"
    "$PYTHON" main.py >> "$LOG_FILE" 2>&1 &
    PYTHON_PID=$!
    wait $PYTHON_PID
    EXIT_CODE=$?
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 終了 (exit=${EXIT_CODE}) - 30秒後に再起動します" >> "$LOG_FILE"
    sleep 30
done
