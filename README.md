# cool-apps-refresh

AI-powered terminal cheat sheet that shows up when you open a new shell. Scans your apt history and zsh history, then uses an AI CLI to generate a compact reminder of the interesting tools you've installed but might forget about.

```
── TERMINAL & SHELL ───────────────────────────────────────────
  glow         Markdown viewer in terminal       glow -p < README.md
  wishlist     CLI task manager                     wishlist list

── NETWORK & SECURITY ─────────────────────────────────────────
  socat        Socket relay/proxy              ⚡ socat TCP-LISTEN:8080,fork TCP:upstream:80
  tailscale    Mesh VPN                        ⚡ tailscale funnel 8080
```

Tools marked with ⚡ haven't appeared in your recent shell history.

## Requirements

- Debian/Ubuntu (reads `/var/log/apt/history.log`)
- zsh (reads `~/.zsh_history`)
- One of the supported AI backends (see below)

## AI backends

Auto-detection tries them in this order, using the first one found:

| Backend | Tool | Notes |
|---------|------|-------|
| `claude` | [Claude Code](https://claude.ai/code) | No API key needed, uses your subscription |
| `llm` | [llm](https://llm.datasette.io/) | Simon Willison's CLI, supports many models |
| `sgpt` | [shell-gpt](https://github.com/TheR1D/shell_gpt) | OpenAI-compatible |
| `aichat` | [aichat](https://github.com/sigoden/aichat) | Multi-provider |
| `custom` | anything | Any command that reads stdin and prints a response |

## Install

```sh
# 1. Copy the script
cp cool-apps-refresh ~/.local/bin/cool-apps-refresh
chmod +x ~/.local/bin/cool-apps-refresh

# 2. Optional: exclusion list (tools to hide from the cheat sheet)
mkdir -p ~/.config/cool-apps
cp exclude.example ~/.config/cool-apps/exclude
# edit it to your liking

# 3. Optional: AI backend config
cp config.example ~/.config/cool-apps/config
# edit AI= to set a backend, or leave as auto

# 4. Show cheat sheet on new terminal — add to ~/.zshrc BEFORE the p10k instant prompt block
() {
  local cache="$HOME/.cache/cool-apps-motd.txt"
  local stamp="$HOME/.cache/cool-apps-shown-date"
  local today
  today=$(date +%Y-%m-%d)
  [[ -f "$cache" ]] || return
  [[ "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return
  cat "$cache"
  echo "$today" > "$stamp"
}

# 5. Install systemd user timer (weekly auto-refresh)
cp cool-apps.service cool-apps.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cool-apps.timer

# 6. Generate the first cheat sheet
cool-apps-refresh
```

## Usage

```sh
cool-apps-refresh            # regenerate (auto-detects backend)
cool-apps-refresh -r
cool-apps-refresh --refresh

cool-apps-refresh -p         # print cached cheat sheet
cool-apps-refresh --print

cool-apps-refresh --ai claude    # force a specific backend
cool-apps-refresh --ai llm
cool-apps-refresh --ai custom    # uses AI_CMD from config
```

## Configuration

Both files live in `~/.config/cool-apps/`.

### `config` — AI backend

```sh
# AI backend: auto, claude, llm, sgpt, aichat, custom
AI=auto

# Required when AI=custom — any command that reads prompt from stdin:
# AI_CMD=ollama run llama3
# AI_CMD=llm -m gpt-4o
```

### `exclude` — hide tools you already know

One package name per line, `#` for comments. See `exclude.example` for a starter list.

```
git
vim
ffmpeg
# add whatever you use daily
```

## How it works

1. Parses `/var/log/apt/history.log` (+ rotated `.gz` files) for manually-installed packages
2. Parses `~/.zsh_history` for recently-used binaries
3. Filters out library packages, system packages, and your exclusion list
4. Pipes the data to your AI backend to generate a categorised cheat sheet
5. Caches the result to `~/.cache/cool-apps-motd.txt`
6. The zshrc snippet displays it once per day on new terminals

## License

MIT
