"""Тонкий клиент к Ollama (/api/chat) с поддержкой tool-calling."""
from __future__ import annotations

import requests

DEFAULT_TIMEOUT = 120


class LLMError(RuntimeError):
    pass


class OllamaClient:
    def __init__(self, host: str, model: str, timeout: int = DEFAULT_TIMEOUT):
        self.host = host.rstrip("/")
        self.model = model
        self.timeout = timeout

    def chat(self, messages: list[dict], tools: list[dict] | None = None) -> dict:
        payload = {"model": self.model, "messages": messages, "stream": False}
        if tools:
            payload["tools"] = tools
        try:
            resp = requests.post(f"{self.host}/api/chat", json=payload, timeout=self.timeout)
        except requests.RequestException as exc:
            raise LLMError(
                f"не удалось подключиться к Ollama на {self.host}: {exc}. "
                "Проверь, что `ollama serve` запущен."
            ) from exc
        if resp.status_code != 200:
            raise LLMError(f"Ollama вернул {resp.status_code}: {resp.text[:500]}")
        data = resp.json()
        message = data.get("message")
        if message is None:
            raise LLMError(f"неожиданный ответ Ollama: {data}")
        return message
