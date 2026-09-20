#!/usr/bin/env python3
"""termux-agent — локальный LLM-агент с tool-calling для Termux/proot на Android.

Запускает REPL или одноразовый запрос против модели в Ollama, даёт модели
инструменты (shell, файлы, OSINT из Xnode-sh/Xnode) и прогоняет цикл
"модель -> вызов инструмента -> результат -> модель" до финального ответа.
"""
from __future__ import annotations

import argparse
import json
import sys

from config import load_config
from llm_client import LLMError, OllamaClient
from tools import TOOL_SCHEMAS, dispatch


def run_conversation(client: OllamaClient, cfg, messages: list[dict]) -> str:
    for _ in range(cfg.max_steps):
        message = client.chat(messages, tools=TOOL_SCHEMAS)
        messages.append(message)

        tool_calls = message.get("tool_calls")
        if not tool_calls:
            return message.get("content", "")

        for call in tool_calls:
            fn = call.get("function", {})
            name = fn.get("name", "")
            args = fn.get("arguments", {})
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except json.JSONDecodeError:
                    args = {}
            print(f"  -> инструмент: {name}({args})", file=sys.stderr)
            result = dispatch(name, args, auto_yes=cfg.auto_yes, xnode_path=cfg.xnode_path)
            messages.append(
                {"role": "tool", "name": name, "content": json.dumps(result, ensure_ascii=False)}
            )

    return "[termux-agent] превышен лимит шагов (max_steps), прерываю"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Локальный LLM-агент для Termux/proot")
    parser.add_argument("prompt", nargs="?", help="Запрос для одноразового режима")
    parser.add_argument("--model", help="Переопределить модель Ollama")
    parser.add_argument("--host", help="Переопределить адрес Ollama")
    parser.add_argument("--config", help="Путь к config.yaml")
    parser.add_argument(
        "--yes", action="store_true", help="Автоподтверждать shell/файловые операции (ОПАСНО)"
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    cfg = load_config(args.config)
    if args.model:
        cfg.model = args.model
    if args.host:
        cfg.host = args.host
    if args.yes:
        cfg.auto_yes = True

    client = OllamaClient(cfg.host, cfg.model)
    messages = [{"role": "system", "content": cfg.system_prompt}]

    try:
        if args.prompt:
            messages.append({"role": "user", "content": args.prompt})
            print(run_conversation(client, cfg, messages))
            return 0

        print(f"termux-agent // модель: {cfg.model} // хост: {cfg.host}")
        print("Ctrl+C или пустая строка для выхода.\n")
        while True:
            try:
                user_input = input("вы> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                break
            if not user_input:
                break
            messages.append({"role": "user", "content": user_input})
            reply = run_conversation(client, cfg, messages)
            print(f"агент> {reply}\n")
    except LLMError as exc:
        print(f"[termux-agent] ошибка: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
