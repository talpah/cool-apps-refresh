#!/bin/sh
# cool-apps-refresh installer
# Usage: curl -fsSL https://raw.githubusercontent.com/talpah/cool-apps-refresh/main/setup.sh | sh

set -eu

REPO="https://raw.githubusercontent.com/talpah/cool-apps-refresh/main"
BIN="$HOME/.local/bin/cool-apps-refresh"
CONFIG_DIR="$HOME/.config/cool-apps"
SYSTEMD_DIR="$HOME/.config/systemd/user"
CACHE_DIR="$HOME/.cache"

# ── colours ──────────────────────────────────────────────────
if [ -t 1 ]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; RESET=''
fi

info()    { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
section() { printf "\n%s\n" "$1"; }
die()     { printf "  ${RED}✗${RESET} %s\n" "$1" >&2; exit 1; }

# ── helpers ───────────────────────────────────────────────────
download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "curl or wget is required"
  fi
}

detect_rcfile() {
  case "${SHELL:-}" in
    */zsh)  echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    *)
      # fallback: check which exists
      if [ -f "$HOME/.zshrc" ]; then echo "$HOME/.zshrc"
      else echo "$HOME/.bashrc"
      fi
      ;;
  esac
}

# ── zshrc snippet ─────────────────────────────────────────────
SNIPPET='
# cool-apps reminder — show once per day in new interactive terminal
() {
  local cache="$HOME/.cache/cool-apps-motd.txt"
  local stamp="$HOME/.cache/cool-apps-shown-date"
  local today
  today=$(date +%Y-%m-%d)
  [[ -f "$cache" ]] || return
  [[ "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return
  cat "$cache"
  echo "$today" > "$stamp"
}'

inject_snippet() {
  rcfile="$1"

  # Already installed?
  if grep -q "cool-apps-motd" "$rcfile" 2>/dev/null; then
    info "Shell snippet already in $rcfile"
    return
  fi

  # If p10k instant prompt is present, insert before it (avoids console output warning)
  if grep -q "p10k-instant-prompt" "$rcfile" 2>/dev/null; then
    python3 - "$rcfile" "$SNIPPET" <<'PYEOF'
import sys
from pathlib import Path

rcfile = Path(sys.argv[1])
snippet = sys.argv[2]
marker = "# Enable Powerlevel10k instant prompt"
content = rcfile.read_text()

if marker in content:
    content = content.replace(marker, snippet.strip() + "\n\n" + marker)
else:
    # p10k source line without the comment
    for line in content.splitlines():
        if "p10k-instant-prompt" in line:
            content = content.replace(line, snippet.strip() + "\n\n" + line)
            break

rcfile.write_text(content)
PYEOF
    info "Shell snippet injected before p10k instant prompt in $rcfile"
  else
    printf '%s\n' "$SNIPPET" >> "$rcfile"
    info "Shell snippet appended to $rcfile"
  fi
}

# ══ main ══════════════════════════════════════════════════════

section "── Installing cool-apps-refresh ──────────────────────"

# 1. binary
mkdir -p "$HOME/.local/bin"
download "$REPO/cool-apps-refresh" > "$BIN"
chmod +x "$BIN"
info "Script installed to $BIN"

# 2. config dir + example files (don't overwrite existing)
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/exclude" ]; then
  download "$REPO/exclude.example" > "$CONFIG_DIR/exclude"
  info "Exclusion list created at $CONFIG_DIR/exclude"
else
  info "Exclusion list already exists — skipping"
fi

if [ ! -f "$CONFIG_DIR/config" ]; then
  download "$REPO/config.example" > "$CONFIG_DIR/config"
  info "AI config created at $CONFIG_DIR/config"
else
  info "AI config already exists — skipping"
fi

# 3. systemd user timer
if command -v systemctl >/dev/null 2>&1; then
  mkdir -p "$SYSTEMD_DIR"
  download "$REPO/cool-apps.service" > "$SYSTEMD_DIR/cool-apps.service"
  download "$REPO/cool-apps.timer"   > "$SYSTEMD_DIR/cool-apps.timer"
  systemctl --user daemon-reload
  systemctl --user enable --now cool-apps.timer
  info "Systemd timer enabled (weekly auto-refresh)"
else
  warn "systemctl not found — skipping timer setup"
fi

# 4. shell snippet
rcfile=$(detect_rcfile)
inject_snippet "$rcfile"

# 5. first run
section "── Generating first cheat sheet ──────────────────────"

# Check if any known AI backend is available
AI_FOUND=0
for backend in claude llm sgpt aichat; do
  if command -v "$backend" >/dev/null 2>&1 || [ -x "$HOME/.local/bin/$backend" ]; then
    AI_FOUND=1
    break
  fi
done

if [ "$AI_FOUND" = "1" ]; then
  "$BIN" && info "Cheat sheet generated at $CACHE_DIR/cool-apps-motd.txt"
else
  warn "No AI backend found — skipping first run"
  warn "Install one of: claude, llm, sgpt, aichat"
  warn "Or set AI=custom + AI_CMD=... in $CONFIG_DIR/config"
  warn "Then run: cool-apps-refresh"
fi

section "── Done ───────────────────────────────────────────────"
printf "  Open a new terminal to see your cheat sheet.\n"
printf "  Edit %s to exclude tools you know well.\n\n" "$CONFIG_DIR/exclude"
