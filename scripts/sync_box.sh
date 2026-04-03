#!/bin/bash
# Boxへのクリップ同期スクリプト（cronから呼び出す）
# cron設定例: 0 * * * * /bin/bash ~/projects/katorilab-corridor-capture/scripts/sync_box.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yaml"

# config.yamlからsave_dir・remote・max_daysを取得
SAVE_DIR=$(python3 -c "
import yaml, os
c = yaml.safe_load(open('$CONFIG'))
print(os.path.expanduser(c['output']['save_dir']))
")
REMOTE=$(python3 -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['sync']['remote'])")
MAX_DAYS=$(python3 -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['storage']['max_days'])")

LOG_FILE="$SCRIPT_DIR/../logs/sync.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同期開始: $SAVE_DIR -> $REMOTE" >> "$LOG_FILE"
rclone sync "$SAVE_DIR" "$REMOTE" --log-file="$LOG_FILE" --log-level INFO

if [ $? -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同期完了" >> "$LOG_FILE"

    # Box同期成功後、max_days日以上経過したローカルファイルを削除
    if [ "$MAX_DAYS" -gt 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${MAX_DAYS}日以上経過したファイルを削除" >> "$LOG_FILE"
        find "$SAVE_DIR" -name "*.mp4" -mtime "+$MAX_DAYS" -delete
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 削除完了" >> "$LOG_FILE"
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同期失敗 - ローカルファイルは削除しない" >> "$LOG_FILE"
fi
