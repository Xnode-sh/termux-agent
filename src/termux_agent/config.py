"""Загрузка конфигурации termux-agent: config.yaml + переменные окружения."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import yaml

DEFAULT_MODEL = "qwen2.5:7b-instruct"
DEFAULT_HOST = "http://127.0.0.1:11434"


@dataclass
class Config:
    model: str = DEFAULT_MODEL
    host: str = DEFAULT_HOST
    auto_yes: bool = False
    max_steps: int = 8
    xnode_path: str | None = None  # путь к клону Xnode-sh/Xnode для OSINT-инструментов
    system_prompt: str = (
        "Ты — локальный агент-ассистент, работающий в Termux/proot на Android. "
        "У тебя есть инструменты (shell, файлы, OSINT). Используй их по одному за раз, "
        "объясняй план перед опасными действиями, отвечай кратко и по-русски."
    )


def load_config(path: str | None = None) -> Config:
    cfg = Config()

    search_paths = [path] if path else ["./termux-agent.yaml", "~/.config/termux-agent/config.yaml"]
    for candidate in search_paths:
        if not candidate:
            continue
        p = Path(candidate).expanduser()
        if p.is_file():
            data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
            for key, value in data.items():
                if hasattr(cfg, key):
                    setattr(cfg, key, value)
            break

    cfg.model = os.environ.get("TERMUX_AGENT_MODEL", cfg.model)
    cfg.host = os.environ.get("TERMUX_AGENT_HOST", cfg.host)
    cfg.xnode_path = os.environ.get("TERMUX_AGENT_XNODE_PATH", cfg.xnode_path)
    if os.environ.get("TERMUX_AGENT_AUTO_YES") == "1":
        cfg.auto_yes = True

    return cfg
