#!/bin/bash
# main.pyを停止するスクリプト

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/../logs/main.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "PIDファイルが見つかりません（起動していない可能性があります）"
    exit 1
fi

PID=$(cat "$PID_FILE")
if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm "$PID_FILE"
    echo "停止しました (PID: $PID)"
else
    echo "プロセスが見つかりません (PID: $PID)"
    rm "$PID_FILE"
fi
