# katorilab-corridor-capture

RTSPカメラの映像から人物を検出し、該当区間のクリップを自動保存・Box同期するシステム。

## 概要

- FFmpegによるRTSPストリームのセグメント録画
- YOLOv8nによる人物検出
- 検出区間を前後バッファ付きでMP4クリップとして保存
- rcloneによるBoxへの定期同期（年度別ディレクトリ）
- Windows起動時の自動実行（タスクスケジューラ + WSL2）

## 動作環境

- Windows 11 + WSL2 (Ubuntu)
- CUDA対応GPU（GTX 1650以上推奨）
- conda
- FFmpeg
- rclone（Box同期を使う場合）

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/JojiOkazaki/katorilab-corridor-capture.git
cd katorilab-corridor-capture
```

### 2. conda環境の作成

```bash
conda env create -f environment.yml
```

### 3. .envの作成

```bash
cp .env.example .env
```

`.env`を編集してカメラの認証情報を設定する：

```
RTSP_HOST=192.168.0.xxx
RTSP_USER=ユーザー名
RTSP_PASS=パスワード
```

### 4. config.yamlの確認・編集

必要に応じて`config.yaml`の各パラメータを調整する。

### 5. rclone設定（Box同期を使う場合）

```bash
rclone config
```

`box`という名前でBoxのリモートを設定する。

## 使い方

### 手動起動・停止

```bash
# 起動
bash scripts/start.sh

# 停止
bash scripts/stop.sh

# ログ確認
tail -f logs/capture.log
```

### Box同期（手動実行）

```bash
bash scripts/sync_box.sh
```

### cronへの登録（定期同期）

```
0 * * * * /bin/bash ~/projects/katorilab-corridor-capture/scripts/sync_box.sh
```

## Windows起動時の自動実行

WSL2を常時起動するタスクと、プログラムを自動起動するタスクの2つをタスクスケジューラに登録する。

### WSL2常時起動タスク

PowerShell（管理者）で実行：

```powershell
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-- sleep infinity"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Days 0)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
Register-ScheduledTask -TaskName "WSL2-KeepAlive" -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

### プログラム自動起動タスク

```powershell
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-- bash /home/<ユーザー名>/projects/katorilab-corridor-capture/scripts/service.sh"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Days 0)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
Register-ScheduledTask -TaskName "Katorilab-Corridor-Capture" -Action $action -Trigger $trigger -Settings $settings -Principal $principal
```

## ディレクトリ構成

```
katorilab-corridor-capture/
├── main.py               # メインスクリプト
├── config.yaml           # 設定ファイル
├── environment.yml       # conda環境定義
├── src/
│   ├── config_loader.py  # 設定読み込み
│   ├── recorder.py       # FFmpegセグメント録画
│   ├── detector.py       # YOLOv8人物検出
│   └── clipper.py        # クリップ保存
├── scripts/
│   ├── start.sh          # 手動起動（バックグラウンド）
│   ├── stop.sh           # 手動停止
│   ├── service.sh        # タスクスケジューラ用起動（ブロッキング）
│   ├── loop.sh           # 再起動ループ（start.shから使用）
│   └── sync_box.sh       # Box同期
└── logs/
    ├── capture.log       # 録画・検出ログ
    └── sync.log          # 同期ログ
```

## 設定項目（config.yaml）

| キー | 説明 | デフォルト |
|------|------|-----------|
| `camera.stream_path` | RTSPストリームパス | `/stream1` |
| `recording.segment_duration` | セグメント長（秒） | `10` |
| `recording.buffer_segments` | 保持セグメント数 | `3` |
| `detection.model` | YOLOモデル | `yolov8n.pt` |
| `detection.confidence_threshold` | 検出信頼度閾値 | `0.3` |
| `clipping.pre_buffer` | 検出前バッファ（秒） | `5` |
| `clipping.post_buffer` | 検出後バッファ（秒） | `5` |
| `storage.max_days` | ローカル保持日数（0=無制限） | `7` |
| `sync.remote` | rcloneリモートパス | - |
