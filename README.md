# termux-agent

Локальный LLM-агент с tool-calling для Termux (proot-distro Ubuntu) на Android.
Часть проекта [RED·TEAM·LAB (@xnode_sh)](https://t.me/xnode_sh) — про Termux,
OSINT и локальные LLM-агенты на Android. Дополняет
[Xnode-sh/Xnode](https://github.com/Xnode-sh/Xnode): там — OSINT-скрипты,
здесь — агент, который умеет ими пользоваться сам.

Никакого облака: модель крутится локально через [Ollama](https://ollama.com),
агент только дирижирует вызовами инструментов.

## Как это работает

1. Ты пишешь запрос (REPL или одна команда).
2. Агент отправляет его модели вместе со списком доступных инструментов
   (JSON-схемы в формате OpenAI/Ollama function-calling).
3. Модель либо отвечает текстом, либо просит вызвать инструмент — агент
   выполняет его и возвращает результат модели, цикл повторяется до
   финального ответа или лимита шагов (`max_steps`, защита от зацикливания).

Инструменты по умолчанию:

| Инструмент     | Что делает                                              | Подтверждение |
|----------------|----------------------------------------------------------|:---:|
| `run_shell`    | выполняет shell-команду                                   | да |
| `read_file`    | читает текстовый файл (до 20 КБ)                           | нет |
| `write_file`   | пишет файл, создавая директории                            | да, при перезаписи |
| `list_dir`     | листинг директории                                          | нет |
| `osint_lookup` | зовёт `email_osint.py` / `username_osint.py` / `phone_osint.py` из локального клона Xnode-sh/Xnode | нет |

`run_shell` и `write_file` по умолчанию спрашивают подтверждение перед
выполнением — агент управляет твоим устройством, и модель может ошибаться
или галлюцинировать команды. Флаг `--yes` / `auto_yes: true` в конфиге
отключает подтверждения — используй только если понимаешь, что делаешь.

## Установка

```bash
# сам Ollama (в Termux — через proot-distro Ubuntu/Debian)
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
ollama pull qwen2.5:7b-instruct   # любая модель с поддержкой tools

git clone https://github.com/Xnode-sh/termux-agent.git
cd termux-agent
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

cp config.example.yaml termux-agent.yaml   # опционально, поправить модель/хост
```

## Использование

```bash
# одноразовый запрос
python3 agent.py "покажи содержимое текущей директории"

# интерактивный REPL
python3 agent.py

# другая модель/хост без правки конфига
python3 agent.py --model llama3.1:8b --host http://127.0.0.1:11434 "..."

# автоподтверждение shell/файловых операций (ОПАСНО, для доверенных сценариев)
python3 agent.py --yes "почисти __pycache__ в этой директории"
```

Интеграция с OSINT-инструментами Xnode: укажи `xnode_path` в
`termux-agent.yaml` (или `TERMUX_AGENT_XNODE_PATH`) на локальный клон
[Xnode-sh/Xnode](https://github.com/Xnode-sh/Xnode) — тогда агент сможет
сам вызывать `osint_lookup` по запросу вроде «пробей username torvalds».

## Конфигурация

Все ключи `config.example.yaml` можно переопределить переменными окружения:
`TERMUX_AGENT_MODEL`, `TERMUX_AGENT_HOST`, `TERMUX_AGENT_XNODE_PATH`,
`TERMUX_AGENT_AUTO_YES=1`.

## Тесты

```bash
python3 -m unittest discover -s tests -v
```

Тесты инструментов и цикла агента используют фейковый LLM-клиент — реальный
Ollama-сервер для CI не нужен.

## Безопасность

Это агент с доступом к shell на твоём устройстве. Держи `auto_yes`/`--yes`
выключенным, если не уверен в модели и промпте; запускай в
Termux/proot-песочнице, а не на голой системе с чувствительными данными.
