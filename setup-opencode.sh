#!/data/data/com.termux/files/usr/bin/bash
# Установка OpenCode в root Termux (ARM64 Android)
# Использование: bash setup-opencode.sh

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; exit 1; }

# --- root-сессия? ---
if [ "$(id -u)" -ne 0 ]; then
  warn "Запущен не от root — некоторые шаги могут потребовать su."
fi

# --- обновление pkg ---
info "Обновление пакетов Termux..."
pkg update -y -o Dpkg::Options::="--force-confnew" 2>/dev/null || true

# --- зависимости ---
info "Установка зависимостей..."
pkg install -y git curl unzip 2>/dev/null || true

# --- bun ---
if command -v bun &>/dev/null; then
  info "bun найден: $(bun --version)"
else
  info "Установка bun..."
  # официальный скрипт, без glibc-repo
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  # добавить в .bashrc
  grep -q '.bun/bin' "$HOME/.bashrc" 2>/dev/null \
    || echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$HOME/.bashrc"
fi

export PATH="$HOME/.bun/bin:$PATH"

# проверка bun
bun --version >/dev/null 2>&1 || err "bun не работает — установи вручную: curl -fsSL https://bun.sh/install | bash"

# --- opencode-termux-setup ---
info "Запуск opencode-termux-setup (sang765)..."
bunx -y "github:sang765/opencode-termux-setup#main"

# --- проверка opencode ---
OC_BIN=""
for p in "$HOME/.local/bin/opencode" "$PREFIX/bin/opencode" "$HOME/.bun/bin/opencode"; do
  [ -x "$p" ] && OC_BIN="$p" && break
done

if [ -z "$OC_BIN" ]; then
  # поищем в PATH
  OC_BIN=$(command -v opencode 2>/dev/null || true)
fi

if [ -n "$OC_BIN" ]; then
  info "OpenCode установлен: $OC_BIN"
  info "Версия: $($OC_BIN --version 2>/dev/null || echo 'неизвестно')"
else
  warn "opencode не найден в PATH после установки."
  warn "Добавь путь вручную или проверь вывод opencode-termux-setup выше."
fi

echo ""
info "Готово. Запуск:"
echo "    cd /путь/к/проекту"
echo "    opencode"
echo ""
warn "Для работы нужен API-ключ — выбери модель при первом запуске."
