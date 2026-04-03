#!/bin/bash
# Boxへのクリップ同期スクリプト（cronから呼び出す）
# cron設定例: 0 * * * * /bin/bash ~/projects/katorilab-corridor-capture/scripts/sync_box.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yaml"

# config.yamlからsave_dirとremoteを取得
SAVE_DIR=$(python3 -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['output']['save_dir'])")
REMOTE=$(python3 -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['sync']['remote'])")

LOG_FILE="$SCRIPT_DIR/../logs/sync.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同期開始: $SAVE_DIR -> $REMOTE" >> "$LOG_FILE"
rclone sync "$SAVE_DIR" "$REMOTE" --log-file="$LOG_FILE" --log-level INFO
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 同期完了" >> "$LOG_FILE"
