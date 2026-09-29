"""Инструменты, доступные локальному агенту, + их JSON-схемы для tool-calling."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Callable

MAX_OUTPUT = 4000


def _confirm(prompt: str, auto_yes: bool) -> bool:
    if auto_yes:
        return True
    try:
        answer = input(f"{prompt} [y/N] ").strip().lower()
    except EOFError:
        return False
    return answer in ("y", "yes", "д", "да")


def run_shell(command: str, auto_yes: bool = False, timeout: int = 60) -> dict:
    """Выполняет shell-команду. ОПАСНО: запускать только с доверенной моделью."""
    if not _confirm(f"Выполнить команду в шелле: {command!r}?", auto_yes):
        return {"ok": False, "error": "отклонено пользователем"}
    try:
        result = subprocess.run(
            command, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return {
            "ok": True,
            "returncode": result.returncode,
            "stdout": result.stdout[-MAX_OUTPUT:],
            "stderr": result.stderr[-MAX_OUTPUT:],
        }
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": f"таймаут {timeout}s"}


def read_file(path: str, max_bytes: int = 20000) -> dict:
    p = Path(path).expanduser()
    if not p.is_file():
        return {"ok": False, "error": "файл не найден"}
    data = p.read_bytes()[:max_bytes]
    return {"ok": True, "content": data.decode("utf-8", errors="replace")}


def write_file(path: str, content: str, auto_yes: bool = False) -> dict:
    p = Path(path).expanduser()
    if p.exists() and not _confirm(f"Файл {p} уже существует, перезаписать?", auto_yes):
        return {"ok": False, "error": "отклонено пользователем"}
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    return {"ok": True, "path": str(p)}


def list_dir(path: str = ".") -> dict:
    p = Path(path).expanduser()
    if not p.is_dir():
        return {"ok": False, "error": "не директория"}
    entries = sorted(x.name + ("/" if x.is_dir() else "") for x in p.iterdir())
    return {"ok": True, "entries": entries}


def osint_lookup(kind: str, target: str, xnode_path: str | None = None) -> dict:
    """Прокси к скриптам Xnode-sh/Xnode (email/username/phone OSINT), если репозиторий доступен локально."""
    script_map = {
        "email": "email_osint.py",
        "username": "username_osint.py",
        "phone": "phone_osint.py",
    }
    if kind not in script_map:
        return {"ok": False, "error": f"неизвестный тип: {kind}, доступно: {list(script_map)}"}
    if not xnode_path:
        return {
            "ok": False,
            "error": "xnode_path не настроен (см. TERMUX_AGENT_XNODE_PATH / config.yaml); "
            "нужен локальный клон https://github.com/Xnode-sh/Xnode",
        }
    script = Path(xnode_path).expanduser() / script_map[kind]
    if not script.is_file():
        return {"ok": False, "error": f"скрипт не найден: {script}"}
    try:
        result = subprocess.run(
            [sys.executable, str(script), target, "--json", "/dev/stdout"],
            capture_output=True,
            text=True,
            timeout=90,
        )
        return {
            "ok": result.returncode == 0,
            "stdout": result.stdout[-MAX_OUTPUT:],
            "stderr": result.stderr[-MAX_OUTPUT:],
        }
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "таймаут 90s"}


# --- JSON-схемы инструментов в формате OpenAI/Ollama function-calling ---

TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "run_shell",
            "description": "Выполнить команду в shell текущего окружения (Termux/proot). Требует подтверждения пользователя.",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "Команда для выполнения"},
                },
                "required": ["command"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Прочитать текстовый файл целиком (до 20000 байт).",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Записать текст в файл, создавая недостающие директории. Требует подтверждения при перезаписи.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_dir",
            "description": "Показать содержимое директории.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string", "default": "."}},
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "osint_lookup",
            "description": "Пассивная OSINT-разведка через скрипты Xnode-sh/Xnode (email, username или phone).",
            "parameters": {
                "type": "object",
                "properties": {
                    "kind": {"type": "string", "enum": ["email", "username", "phone"]},
                    "target": {"type": "string"},
                },
                "required": ["kind", "target"],
            },
        },
    },
]

REGISTRY: dict[str, Callable] = {
    "run_shell": run_shell,
    "read_file": read_file,
    "write_file": write_file,
    "list_dir": list_dir,
    "osint_lookup": osint_lookup,
}


def dispatch(name: str, args: dict, *, auto_yes: bool, xnode_path: str | None) -> dict:
    fn = REGISTRY.get(name)
    if fn is None:
        return {"ok": False, "error": f"неизвестный инструмент: {name}"}
    kwargs = dict(args)
    if name in ("run_shell", "write_file"):
        kwargs.setdefault("auto_yes", auto_yes)
    if name == "osint_lookup":
        kwargs.setdefault("xnode_path", xnode_path)
    try:
        return fn(**kwargs)
    except TypeError as exc:
        return {"ok": False, "error": f"неверные аргументы: {exc}"}
