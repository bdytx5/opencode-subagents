---
name: opencode
description: Ask OpenCode (free models) for ideas, second opinions, or run OpenCode as parallel subagents from Claude Code. Use when the user says "ask opencode", "get ideas from opencode", "have opencode do X", "spawn opencode subagents", "use GLM / DeepSeek", or wants cheap/free model help.
---

# OpenCode from Claude Code

OpenCode is an open-source coding agent. Its free models need no API key. Install it with `curl -fsSL https://opencode.ai/install | bash` if `opencode` is not found (it lands in `~/.opencode/bin/opencode`).

## First use: ask about voice mode

The first time this skill runs on a machine (no file `~/.opencode_work/.voice_mode_asked`), ask the user once, with AskUserQuestion:

"Do you want voice mode? Handy is a free, open-source app that turns your speech into text in any window (it works offline), so you can talk to Claude and OpenCode instead of typing."

- Yes, install Handy: on macOS with Homebrew run `brew install --cask handy`; otherwise send the user to https://handy.computer to download it. Check that it installed (`ls /Applications | grep -i handy` on macOS), open it (`open -a Handy`), and tell the user to pick a shortcut key in Handy's settings and allow microphone and accessibility access when macOS asks.
- Already have it / No: do nothing.

Then write the answer to `~/.opencode_work/.voice_mode_asked` (create the folder if needed) so the question is never asked again, and carry on with the task.

## Models (pass with `-m`)

- `opencode/glm-5.3-flash-free` (GLM 5.3 Flash)
- `opencode/deepseek-v4.1-flash-free` (DeepSeek V4.1 Flash)

The free model list changes over time. If a model is not found, or the user names another one, run `opencode models --refresh | grep -i <name>` to find the exact id.

## Core command

```
opencode run -m <model> --dir <project dir> "<prompt>" [-f file ...]
```

Always put the prompt BEFORE any `-f` flag. `-f` takes a list and swallows the prompt as a file name if it comes first ("File not found").

`opencode run` is non-interactive: it prints the answer and exits. It has no memory of this conversation, so the prompt must carry all the context.

## Asking for ideas (one model, or both for two opinions)

1. Write a self-contained prompt to a scratch file: the goal, the background in plain words, what has already been tried or ruled out, constraints, and exactly what kind of answer is wanted (for example "10 distinct ideas, one line each, then the 3 most promising with reasons").
2. Attach real files with `-f path` (repeat the flag) instead of pasting them. Use `--dir` so it can read the project.
3. Run it with `run_in_background: true` if it may take more than a minute. For two opinions, run both models at the same time in separate background Bash calls.
4. Read the output and give the user the ideas, saying which model produced which. Treat them as suggestions: check anything factual before relying on it.

Example:
```
opencode run -m opencode/deepseek-v4.1-flash-free --dir "$PWD" "$(cat /path/to/prompt.txt)" -f notes.md
```

## Subagents (parallel workers)

Split the job into independent pieces (for example a list of items divided into groups). For each piece:

1. Make its own small folder, e.g. `~/.opencode_work/<job>_<n>/`, and write its full prompt to `prompt.txt` there. Ask it to write its result to `result.md` in that folder.
2. Launch it in the background from that folder:
   ```
   cd ~/.opencode_work/<job>_<n> && nohup opencode run --auto -m <model> --dir "$PWD" --title "<job>_<n>" "$(cat prompt.txt)" > run.log 2>&1 &
   ```
3. Start one background watcher that waits until no worker is left (`until [ $(pgrep -f "title <job>_" | wc -l) -eq 0 ]; do sleep 60; done`) and then lists which `result.md` files exist. Do not poll in the foreground.
4. When they finish, read every `result.md` (and `run.log` for any worker without a result), verify the important claims yourself, and report per worker: which model, what it found, where it failed.

Different workers must never edit the same files. `--auto` approves every tool call: use it only for work the user asked for, and keep each worker in its own folder. Never hand a worker secrets or credentials. Free models are weaker than Claude: give narrow, concrete tasks and check what comes back.

To continue a worker's session: `opencode run -s <session id> "<follow-up>"`. `--format json` prints raw events, including the session id.

## When the user says to use GLM or DeepSeek "with OpenCode" for a task

That is a delegation (or a test) of the task itself. Pass the user's request in their own words and let the model work out every step. Do not investigate first, do not add hints or a plan to its prompt, and do not quietly finish the job for it if it fails. Only add obvious safety limits (for example "read-only, change nothing"). Report what the model did and answered, quoting its real output, including where it failed.

## Visible mode (macOS only)

To watch a run live in a Terminal window:

```
~/bin/oc_watch opencode/glm-5.3-flash-free "<the user's request in their own words>"
```

It runs the task in one reusable Terminal window at the top-left of the screen without stealing focus. The window ends with "[finished]". To read the result, read that window's history with osascript by its window id (find it by the text "OpenCode live run" and "[finished]"; never match on text that also appears in the Claude window). It runs one task at a time; use background subagents for parallel work.

## Hard rules learned the hard way

- NEVER run OpenCode with the home folder as its directory (`--dir ~` or `cd ~`) if the home folder is a git repo: OpenCode scans it and hangs with no output. Always run from a small folder such as `~/.opencode_work`. OpenCode can still read any file by its full path.
- Non-interactive runs block forever on a permission prompt. Either pass `--auto`, or set permissions to "allow" in `~/.config/opencode/opencode.json` (the installer offers this).
