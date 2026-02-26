#!/bin/sh
# cool-apps-refresh installer
# Usage: curl -fsSL https://raw.githubusercontent.com/talpah/cool-apps-refresh/main/setup.sh | sh

set -eu

REPO="https://raw.githubusercontent.com/talpah/cool-apps-refresh/main"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/cool-apps-refresh"
CONFIG_DIR="$HOME/.config/cool-apps"

# ── colours ──────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
else
  BOLD=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

info()    { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn()    { printf "  ${YELLOW}!${RESET} %s\n" "$1"; }
skip()    { printf "  ${CYAN}-${RESET} %s\n" "$1"; }
header()  { printf "\n${BOLD}%s${RESET}\n" "$1"; }
die()     { printf "\n  ✗ %s\n" "$1" >&2; exit 1; }

# ── prompt y/n ────────────────────────────────────────────────
confirm() {
  printf "  %s [y/N] " "$1"
  read -r answer </dev/tty
  case "$answer" in [yY]*) return 0 ;; *) return 1 ;; esac
}

# ── download ──────────────────────────────────────────────────
download() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    die "curl or wget is required"
  fi
}

# ── shell detection ───────────────────────────────────────────
detect_shell() {
  # Prefer the running shell, fall back to $SHELL
  _shell="${SHELL:-sh}"
  case "$_shell" in
    */zsh)  echo "zsh"  ;;
    */bash) echo "bash" ;;
    */fish) echo "fish" ;;
    */ksh)  echo "ksh"  ;;
    *)      echo "unknown" ;;
  esac
}

rcfile_for() {
  case "$1" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bashrc" ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    ksh)  echo "$HOME/.kshrc" ;;
    *)    echo "" ;;
  esac
}

# ── shell snippets ────────────────────────────────────────────
# zsh / bash / ksh: uses () anonymous function + [[ ]]
SNIPPET_SH='
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

# fish: uses a function
SNIPPET_FISH='
# cool-apps reminder — show once per day in new interactive terminal
function _cool_apps_reminder
  set cache "$HOME/.cache/cool-apps-motd.txt"
  set stamp "$HOME/.cache/cool-apps-shown-date"
  set today (date +%Y-%m-%d)
  test -f "$cache" || return
  test "$(cat "$stamp" 2>/dev/null)" = "$today" && return
  cat "$cache"
  echo "$today" > "$stamp"
end
_cool_apps_reminder'

# ── timer / cron setup ────────────────────────────────────────
setup_timer() {
  if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
    # systemd user session available
    _sdir="$HOME/.config/systemd/user"
    printf "  Install a weekly systemd user timer to auto-refresh the cheat sheet?\n"
    if confirm "Enable cool-apps.timer?"; then
      mkdir -p "$_sdir"
      download "$REPO/cool-apps.service" > "$_sdir/cool-apps.service"
      download "$REPO/cool-apps.timer"   > "$_sdir/cool-apps.timer"
      systemctl --user daemon-reload
      systemctl --user enable --now cool-apps.timer
      info "Systemd timer enabled (runs every Sunday at 10:00)"
    else
      skip "Skipped timer — run 'cool-apps-refresh' manually to regenerate"
    fi
  else
    # Offer cron as fallback
    printf "  systemd user session not available. Install a weekly cron job instead?\n"
    if confirm "Add cron job?"; then
      _cron_line="0 10 * * 0 $BIN"
      ( crontab -l 2>/dev/null | grep -v "cool-apps-refresh"; echo "$_cron_line" ) | crontab -
      info "Cron job added: $BIN every Sunday at 10:00"
    else
      skip "Skipped auto-refresh — run 'cool-apps-refresh' manually"
    fi
  fi
}

# ── shell snippet injection ───────────────────────────────────
setup_shell() {
  _shell="$1"
  _rcfile="$2"
  _snippet="$3"

  if [ -z "$_rcfile" ]; then
    warn "Unknown shell '$_shell' — skipping shell integration"
    warn "Manually add the snippet from the README to your shell config"
    return
  fi

  if grep -q "cool-apps-motd" "$_rcfile" 2>/dev/null; then
    skip "Shell snippet already in $_rcfile"
    return
  fi

  printf "  Add a snippet to %s to show the cheat sheet once per day?\n" "$_rcfile"
  if ! confirm "Add shell snippet?"; then
    skip "Skipped shell snippet"
    return
  fi

  # zsh: inject before p10k instant prompt if present
  if [ "$_shell" = "zsh" ] && grep -q "p10k-instant-prompt" "$_rcfile" 2>/dev/null; then
    python3 - "$_rcfile" "$_snippet" <<'PYEOF'
import sys
from pathlib import Path
rcfile, snippet = Path(sys.argv[1]), sys.argv[2]
content = rcfile.read_text()
marker = next(
    (l for l in content.splitlines() if "p10k-instant-prompt" in l),
    None
)
if marker:
    content = content.replace(marker, snippet.strip() + "\n\n" + marker, 1)
    rcfile.write_text(content)
PYEOF
    info "Snippet injected before p10k instant prompt in $_rcfile"
  else
    printf '\n%s\n' "$_snippet" >> "$_rcfile"
    info "Snippet appended to $_rcfile"
  fi
}

# ══ main ══════════════════════════════════════════════════════

printf "\n${BOLD}cool-apps-refresh installer${RESET}\n"
printf "────────────────────────────────────────────────────\n"
printf "  Detected shell : %s\n" "$(detect_shell)"
printf "  Install dir    : %s\n" "$BIN_DIR"
printf "  Config dir     : %s\n" "$CONFIG_DIR"
printf "────────────────────────────────────────────────────\n"

# ── 1. binary ────────────────────────────────────────────────
header "1/4  Script"
if [ -f "$BIN" ]; then
  mkdir -p "$BIN_DIR"
  download "$REPO/cool-apps-refresh" > "$BIN"
  chmod +x "$BIN"
  info "Script updated"
else
  if confirm "Install cool-apps-refresh to $BIN?"; then
    mkdir -p "$BIN_DIR"
    download "$REPO/cool-apps-refresh" > "$BIN"
    chmod +x "$BIN"
    info "Installed to $BIN"
  else
    die "Script is required — aborting"
  fi
fi

# ── 2. config files ───────────────────────────────────────────
header "2/4  Config"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/exclude" ]; then
  if confirm "Create exclusion list at $CONFIG_DIR/exclude?"; then
    download "$REPO/exclude.example" > "$CONFIG_DIR/exclude"
    info "Created $CONFIG_DIR/exclude — edit it to hide tools you know well"
  else
    skip "Skipped exclusion list"
  fi
else
  skip "$CONFIG_DIR/exclude already exists"
fi

if [ ! -f "$CONFIG_DIR/config" ]; then
  if confirm "Create AI backend config at $CONFIG_DIR/config?"; then
    download "$REPO/config.example" > "$CONFIG_DIR/config"
    info "Created $CONFIG_DIR/config — edit AI= to set your backend"
  else
    skip "Skipped AI config (defaults to auto-detect)"
  fi
else
  skip "$CONFIG_DIR/config already exists"
fi

# ── 3. timer / cron ──────────────────────────────────────────
header "3/4  Auto-refresh"
setup_timer

# ── 4. shell integration ─────────────────────────────────────
header "4/4  Shell integration"
_shell=$(detect_shell)
_rcfile=$(rcfile_for "$_shell")

if [ "$_shell" = "fish" ]; then
  setup_shell "fish" "$_rcfile" "$SNIPPET_FISH"
else
  setup_shell "$_shell" "$_rcfile" "$SNIPPET_SH"
fi

# ── first run ─────────────────────────────────────────────────
header "Done"

AI_FOUND=0
for _b in claude llm sgpt aichat; do
  if command -v "$_b" >/dev/null 2>&1 || [ -x "$BIN_DIR/$_b" ]; then
    AI_FOUND=1; break
  fi
done

if [ "$AI_FOUND" = "1" ]; then
  if confirm "Generate your first cheat sheet now?"; then
    "$BIN"
  fi
else
  warn "No AI backend found (claude / llm / sgpt / aichat)"
  warn "Install one, or set AI=custom + AI_CMD=... in $CONFIG_DIR/config"
  warn "Then run: cool-apps-refresh"
fi

printf "\n  Open a new terminal (or run 'source %s') to see your cheat sheet.\n\n" "${_rcfile:-your shell config}"
