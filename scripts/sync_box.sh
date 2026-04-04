#!/bin/bash
# Boxへのクリップ同期スクリプト（cronから呼び出す）
# cron設定例: 0 * * * * /bin/bash ~/projects/katorilab-corridor-capture/scripts/sync_box.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yaml"
LOG_FILE="$SCRIPT_DIR/../logs/sync.log"

# conda環境のPythonを使用（pyyamlのため）
CONDA_PYTHON="$HOME/miniconda3/envs/katorilab-corridor-capture/bin/python3"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# config.yamlから設定を読み込む
SAVE_DIR=$("$CONDA_PYTHON" -c "
import yaml, os
c = yaml.safe_load(open('$CONFIG'))
print(os.path.expanduser(c['output']['save_dir']))
")
REMOTE=$("$CONDA_PYTHON" -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['sync']['remote'])")
MAX_DAYS=$("$CONDA_PYTHON" -c "import yaml; c=yaml.safe_load(open('$CONFIG')); print(c['storage']['max_days'])")

# Box接続確認
log "Box接続確認..."
if ! rclone lsd "$REMOTE" > /dev/null 2>&1; then
    log "ERROR: Box接続失敗 - 同期をスキップ（ローカルファイルは保持）"
    exit 1
fi
log "Box接続OK"

# ファイル名（YYYYMMDD_...）から日本の年度を計算する関数
# 4月〜12月: その年が年度 / 1月〜3月: 前年が年度
get_fiscal_year() {
    local filename="$1"
    local year="${filename:0:4}"
    local month="${filename:4:2}"
    if [ "$month" -ge 4 ]; then
        echo "$year"
    else
        echo $((year - 1))
    fi
}

# ファイルをファイル名の年度ごとにBoxへアップロード
log "アップロード開始: $SAVE_DIR -> $REMOTE"
upload_ok=0
upload_fail=0

for file in "$SAVE_DIR"/*.mp4; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    fiscal_year=$(get_fiscal_year "$filename")
    remote_dir="$REMOTE/$fiscal_year"

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

    find "$SAVE_DIR" -name "*.mp4" -mtime "+$MAX_DAYS" | while read -r file; do
        filename=$(basename "$file")
        fiscal_year=$(get_fiscal_year "$filename")
        remote_path="$REMOTE/$fiscal_year/$filename"

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
