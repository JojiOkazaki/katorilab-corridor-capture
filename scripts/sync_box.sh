#!/bin/bash
# Boxへのクリップ同期スクリプト（cronから呼び出す）
# cron設定例: 0 * * * * /bin/bash ~/projects/katorilab-corridor-capture/scripts/sync_box.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yaml"
LOG_FILE="$SCRIPT_DIR/../logs/sync.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# config.yamlから設定を読み込む
SAVE_DIR=$(python3 -c "
import yaml, os
c = yaml.safe_load(open('$CONFIG'))
print(os.path.expanduser(c['output']['save_dir']))
")
REMOTE=$(python3 -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['sync']['remote'])")
MAX_DAYS=$(python3 -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['storage']['max_days'])")

# Box接続確認
log "Box接続確認..."
if ! rclone lsd "$REMOTE" > /dev/null 2>&1; then
    log "ERROR: Box接続失敗 - 同期をスキップ（ローカルファイルは保持）"
    exit 1
fi
log "Box接続OK"

# ファイルをファイル名の年度ごとにBoxへアップロード
log "アップロード開始: $SAVE_DIR -> $REMOTE"
upload_ok=0
upload_fail=0

for file in "$SAVE_DIR"/*.mp4; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    file_year="${filename:0:4}"  # ファイル名YYYYMMDD_...から年度を取得
    remote_dir="$REMOTE/$file_year"

    if rclone copy "$file" "$remote_dir/" --log-file="$LOG_FILE" --log-level INFO 2>&1; then
        upload_ok=$((upload_ok + 1))
    else
        log "WARN: アップロード失敗: $filename"
        upload_fail=$((upload_fail + 1))
    fi
done

log "アップロード完了: 成功=${upload_ok}, 失敗=${upload_fail}"

# max_days日以上経過したローカルファイルをBoxの存在確認後に削除
if [ "$MAX_DAYS" -gt 0 ]; then
    log "${MAX_DAYS}日以上経過したファイルの削除チェック開始"
    delete_ok=0
    delete_skip=0

    find "$SAVE_DIR" -name "*.mp4" -mtime "+$MAX_DAYS" | while read -r file; do
        filename=$(basename "$file")
        file_year="${filename:0:4}"
        remote_path="$REMOTE/$file_year/$filename"

        # Box上に存在することを確認してから削除
        if rclone ls "$remote_path" > /dev/null 2>&1; then
            rm "$file"
            log "削除: $filename"
        else
            log "WARN: Box上に見つからないためスキップ: $filename"
        fi
    done

    log "削除チェック完了"
fi

log "処理完了"
