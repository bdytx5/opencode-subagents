#!/usr/bin/env bash
# Installs the OpenCode subagents skill for Claude Code.
#   - installs OpenCode if it is missing
#   - copies the skill to ~/.claude/skills/opencode and the launchers to ~/bin
#   - optionally lets OpenCode run without permission prompts (needed for background workers)
#   - optionally installs Handy (free offline speech-to-text) for voice mode
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ask() { read -r -p "$1 [y/N] " a ; [[ "$a" =~ ^[Yy] ]]; }

echo "[1/5] OpenCode"
if command -v opencode >/dev/null || [ -x "$HOME/.opencode/bin/opencode" ]; then echo "  already installed"
else curl -fsSL https://opencode.ai/install | bash; fi

echo "[2/5] Skill -> ~/.claude/skills/opencode"
mkdir -p "$HOME/.claude/skills/opencode"
cp "$HERE/skills/opencode/SKILL.md" "$HOME/.claude/skills/opencode/SKILL.md"

echo "[3/5] Launchers and helpers -> ~/bin/oc_tui, oc_tab, oc_watch, oc_wait, oc_say (visible mode, macOS only)"
mkdir -p "$HOME/bin" "$HOME/.opencode_work"
for f in oc_watch oc_tui oc_tab oc_wait oc_say; do cp "$HERE/bin/$f" "$HOME/bin/$f"; chmod +x "$HOME/bin/$f"; done

echo "[4/5] OpenCode permissions"
CFG="$HOME/.config/opencode/opencode.json"
if [ -f "$CFG" ]; then
  echo "  $CFG already exists, left unchanged. Background workers use --auto, so this is optional."
elif ask "  Let OpenCode run commands, edit files and fetch web pages without asking (recommended for subagents)?"; then
  mkdir -p "$(dirname "$CFG")"
  cat > "$CFG" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/glm-5.3-flash-free",
  "permission": { "bash": "allow", "edit": "allow", "webfetch": "allow", "external_directory": "allow" }
}
JSON
  echo "  wrote $CFG"
fi

echo "[5/5] Voice mode"
if ask "  Do you want voice mode? It installs Handy, a free offline app that types what you say into any window."; then
  if [ "$(uname)" = Darwin ] && command -v brew >/dev/null; then
    brew install --cask handy && open -a Handy || true
    echo "  Handy installed. Pick a shortcut key in its settings and allow microphone + accessibility access."
  else
    echo "  Download Handy from https://handy.computer"
  fi
  echo yes > "$HOME/.opencode_work/.voice_mode_asked"
else
  echo no > "$HOME/.opencode_work/.voice_mode_asked"
fi
echo "Done. In Claude Code, try: \"ask opencode for 5 ideas to speed up this script\""
