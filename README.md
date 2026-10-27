# OpenCode subagents for Claude Code

A Claude Code skill that lets Claude hand work to [OpenCode](https://opencode.ai) running free models (GLM 5.3 Flash and DeepSeek V4.1 Flash, no API key needed):

- **Ideas and second opinions:** "ask opencode for ideas on X", or ask both models and compare.
- **Parallel subagents:** "spawn a few GLM and DeepSeek subagents to do X". Claude splits the job, runs each piece as a background OpenCode worker in its own folder, waits, then checks and reports what each model found.
- **Visible mode (macOS):** watch a run live in a Terminal window.
- **Voice mode (optional):** installs [Handy](https://handy.computer), a free, offline speech-to-text app, so you can talk instead of type.

## Install

```
git clone https://github.com/bdytx5/opencode-subagents.git
cd opencode-subagents
./install.sh
```

The installer:
1. Installs OpenCode if you don't have it.
2. Copies the skill to `~/.claude/skills/opencode/`.
3. Copies the launcher to `~/bin/oc_watch`.
4. Offers to let OpenCode run without permission prompts.
5. Asks whether you want voice mode (Handy).

If you skip the installer, the skill asks about voice mode the first time it runs.

## Use

In Claude Code, say things like:

- "ask opencode for 10 ideas to make this faster"
- "get a second opinion from GLM and DeepSeek on this bug"
- "spawn 3 GLM and 3 DeepSeek subagents with opencode to research X for each of these 20 items"

## Notes

- The free models are weaker than Claude, so Claude verifies their results before relying on them.
- Background workers run with `--auto` (no permission prompts) inside their own folder under `~/.opencode_work/`.
- Don't run OpenCode with your home folder as its working directory if your home folder is a git repo: it scans the whole thing and hangs.
