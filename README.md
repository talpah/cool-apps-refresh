# cool-apps-refresh

AI-powered terminal cheat sheet that shows up when you open a new shell. Scans your package manager history and shell history, then uses an AI CLI to generate a compact reminder of the interesting tools you've installed but might forget about.

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

## How it works

1. Collects installed packages from all detected package managers (apt, pacman, dnf, zypper, snap, flatpak, brew)
2. Parses shell history for recently-used binaries (zsh, bash, fish, ksh — whichever are present)
3. Filters out library packages, system packages, and your exclusion list
4. Pipes the merged data to your AI backend to generate a categorised cheat sheet
5. Caches the result to `~/.cache/cool-apps-motd.txt`
6. The shell snippet displays it once per day when you open a new terminal

## Requirements

- Python 3.8+
- At least one supported shell (zsh, bash, fish, or ksh)
- At least one supported package manager (see below)
- One of the supported AI backends (see AI backends)

## Package managers

History is collected from whichever of these are present — all are optional:

| Package manager | Source | Distro / OS |
|-----------------|--------|-------------|
| apt | `/var/log/apt/history.log` (+ `.gz` rotations) | Debian, Ubuntu |
| pacman | `/var/log/pacman.log` | Arch Linux |
| dnf | `/var/log/dnf.rpm.log` | Fedora, RHEL 8+ |
| yum | `/var/log/yum.log` | CentOS, RHEL 7 |
| zypper | `/var/log/zypp/history` | openSUSE |
| snap | `snap list` | cross-distro |
| flatpak | `flatpak list` | cross-distro |
| brew | `brew list` | macOS, Linux |

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

The installer asks for confirmation before each step. It will offer to:

1. Install `cool-apps-refresh` to `~/.local/bin/`
2. Create `~/.config/cool-apps/exclude` and `config` (skips if already present)
3. Enable a weekly systemd user timer (or cron job as fallback)
4. Inject the shell snippet into your rc file (zsh, bash, fish, ksh supported)
5. Generate the first cheat sheet

The script is idempotent — safe to re-run.

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

# 4. Add to your shell rc file BEFORE the p10k instant prompt block (zsh)
#    or anywhere in .bashrc / config.fish
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

### `config` — AI backend and output size

```sh
# AI backend: auto, claude, llm, sgpt, aichat, custom
AI=auto

# Required when AI=custom — any command that reads prompt from stdin:
# AI_CMD=ollama run llama3
# AI_CMD=llm -m gpt-4o

# Max lines in the generated cheat sheet (default: 45)
# Increase for a longer sheet, decrease for a quick glance
# MAX_LINES=30
# MAX_LINES=80
```

### `exclude` — hide tools you already know

One package name per line, `#` for comments. See `exclude.example` for a starter list.

```
git
vim
ffmpeg
# add whatever you use daily
```

## License

MIT
