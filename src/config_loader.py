import os
from pathlib import Path

import yaml
from dotenv import load_dotenv


def load_config(config_path: str | Path = "config.yaml") -> dict:
    load_dotenv()

    with open(config_path) as f:
        config = yaml.safe_load(f)

    host = os.environ["RTSP_HOST"]
    user = os.environ["RTSP_USER"]
    password = os.environ["RTSP_PASS"]
    port = config["camera"]["port"]
    stream_path = config["camera"]["stream_path"]

    config["camera"]["rtsp_url"] = f"rtsp://{user}:{password}@{host}:{port}{stream_path}"

    return config
