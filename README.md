# cool-apps-refresh

AI-powered terminal cheat sheet that shows up when you open a new shell. Scans your apt history and zsh history, then uses Claude to generate a compact reminder of the interesting tools you've installed but might forget about.

```
── TERMINAL & SHELL ───────────────────────────────────────────
  glow         Markdown viewer in terminal    glow -p < README.md
  wishlist     CLI task manager               wishlist list

── NETWORK & SECURITY ─────────────────────────────────────────
  socat        Socket relay/proxy             ⚡ socat TCP-LISTEN:8080,fork TCP:upstream:80
  tailscale    Mesh VPN                       ⚡ tailscale funnel 8080
```

Tools marked with ⚡ haven't appeared in your recent shell history.

## Requirements

- Debian/Ubuntu (reads `/var/log/apt/history.log`)
- zsh (reads `~/.zsh_history`)
- [Claude Code](https://claude.ai/code) — uses `claude -p` for generation (no API key needed)

## Install

```sh
# 1. Copy the script
cp cool-apps-refresh ~/.local/bin/cool-apps-refresh
chmod +x ~/.local/bin/cool-apps-refresh

# 2. Optional: exclusion list (tools to hide from the cheat sheet)
mkdir -p ~/.config/cool-apps
cp exclude.example ~/.config/cool-apps/exclude
# edit it to your liking

# 3. Show cheat sheet on new terminal — add to ~/.zshrc BEFORE the p10k instant prompt block
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

# 4. Install systemd user timer (weekly auto-refresh)
cp cool-apps.service cool-apps.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now cool-apps.timer

# 5. Generate the first cheat sheet
cool-apps-refresh
```

## Usage

```sh
cool-apps-refresh          # regenerate cheat sheet
cool-apps-refresh -r       # same
cool-apps-refresh --refresh

cool-apps-refresh -p       # print cached cheat sheet
cool-apps-refresh --print
```

## Exclusion list

Add package names to `~/.config/cool-apps/exclude` (one per line, `#` for comments) to hide tools you already know well. See `exclude.example` for a starter list.

## How it works

1. Parses `/var/log/apt/history.log` (+ rotated `.gz` files) for manually-installed packages
2. Parses `~/.zsh_history` for recently-used binaries
3. Filters out library packages, system packages, and your exclusion list
4. Sends the data to `claude -p` (Claude Code) to generate a categorised cheat sheet
5. Caches the result to `~/.cache/cool-apps-motd.txt`
6. The zshrc snippet displays it once per day on new terminals

## License

MIT
