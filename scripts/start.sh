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

(
    PYTHON_PID=""

    # stop.shからSIGTERMを受け取ったらPythonプロセスも終了してループを抜ける
    trap '
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] 停止シグナル受信" >> "$LOG_FILE"
        [ -n "$PYTHON_PID" ] && kill "$PYTHON_PID" 2>/dev/null
        rm -f "$PID_FILE"
        exit 0
    ' SIGTERM SIGINT

    # 再起動ループ: 異常終了時は30秒待って再起動
    while true; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] main.py 起動" >> "$LOG_FILE"
        python main.py >> "$LOG_FILE" 2>&1 &
        PYTHON_PID=$!
        wait $PYTHON_PID
        EXIT_CODE=$?

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 終了 (exit=${EXIT_CODE}) - 30秒後に再起動します" >> "$LOG_FILE"
        sleep 30
    done
) &

echo $! > "$PID_FILE"
echo "起動完了 (PID: $!)"
