#!/data/data/com.termux/files/usr/bin/bash
# Быстрый запуск OpenCode в root Termux без лагов

# убираем LD_PRELOAD (главная причина глюков в root termux)
unset LD_PRELOAD

# простой терминал — меньше escape-последовательностей
export TERM=xterm-256color

# отключаем mouse tracking — основная причина лагов в TUI на Termux
export OPENCODE_NO_MOUSE=1
printf '\033[?1003l'  # сбросить any-event mouse
printf '\033[?1002l'  # сбросить button-event mouse
printf '\033[?1000l'  # сбросить normal mouse

# bun: отключаем тяжёлый DFG JIT, оставляем базовый — быстрее на ARM64
export BUN_JSC_useDFGJIT=0
export BUN_JSC_useFTLJIT=0

# размер терминала (фиксим если 0x0)
if [ "${COLUMNS:-0}" -eq 0 ] || [ "${LINES:-0}" -eq 0 ]; then
  stty rows 40 cols 120 2>/dev/null || true
fi

exec opencode "$@"
