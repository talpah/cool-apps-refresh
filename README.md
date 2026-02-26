# cool-apps-refresh

AI-powered terminal cheat sheet that shows up when you open a new shell. Scans your apt history and zsh history, then uses an AI CLI to generate a compact reminder of the interesting tools you've installed but might forget about.

```
── KUBERNETES ────────────────────────────────────────
  k9s        K8s TUI dashboard    ⚡ k9s -A
  kubectl    Cluster control         kubectl get pods -A

── NETWORK ───────────────────────────────────────────
  socat      TCP/socket relay     ⚡ socat TCP-LISTEN:8080,fork TCP:localhost:3000
  tailscale  Mesh VPN             ⚡ tailscale funnel 8080

── FILES & MEDIA ─────────────────────────────────────
  glow       Markdown viewer         glow -p README.md
  chafa      Image → ANSI art     ⚡ chafa --colors 256 photo.jpg
  trash-cli  Trash-bin delete        trash-put ./old-dir/

── DEVELOPMENT ───────────────────────────────────────
  gh         GitHub CLI              gh pr list --state open
  glab       GitLab CLI           ⚡ glab mr list --state opened
  oathtool   TOTP code generator  ⚡ oathtool --totp -b SECRET
  btop       Resource monitor        btop
  acli       Atlassian/Jira CLI   ⚡ acli issue list
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
curl -fsSL https://raw.githubusercontent.com/talpah/cool-apps-refresh/main/setup.sh | sh
```

The script is idempotent — safe to re-run. It will:

1. Install `cool-apps-refresh` to `~/.local/bin/`
2. Create `~/.config/cool-apps/exclude` and `config` (skips if already present)
3. Enable a weekly systemd user timer for auto-refresh
4. Inject the shell snippet into `~/.zshrc` (before p10k instant prompt if present)
5. Generate the first cheat sheet

### Manual install

<details>
<summary>Step-by-step without the installer</summary>

```sh
# 1. Copy the script
cp cool-apps-refresh ~/.local/bin/cool-apps-refresh
chmod +x ~/.local/bin/cool-apps-refresh

# 2. Optional: exclusion list
mkdir -p ~/.config/cool-apps
cp exclude.example ~/.config/cool-apps/exclude

# 3. Optional: AI backend config
cp config.example ~/.config/cool-apps/config

# 4. Add to ~/.zshrc BEFORE the p10k instant prompt block
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

# 5. Install systemd user timer
cp cool-apps.service cool-apps.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cool-apps.timer

# 6. Generate the first cheat sheet
cool-apps-refresh
```

</details>

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
