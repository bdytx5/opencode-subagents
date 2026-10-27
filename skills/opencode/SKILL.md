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

## How a subagent tells Claude it finished, has a question, or is stuck

An OpenCode worker cannot call Claude directly, so the two sides use plain files in the worker's own folder (`~/.opencode_work/<job>_<n>/`) and two small tools. Claude is woken by a background command ending, so nothing is polled and no tokens are spent waiting.

**Put these rules in EVERY worker prompt** (copy the block word for word, with the worker's folder filled in):

```
HOW TO REPORT BACK TO CLAUDE. Your folder is <FOLDER>. Use only these files in it:
- When your task is completely finished: write your answer to result.md first, then create an empty file named DONE.
- If you need a decision or information only the user or Claude can give: write your question (what you need, what you already tried, the options you see) to QUESTION.md, then stop and wait. Claude will type the answer into this screen.
- If you cannot continue (a tool or source is broken, a limit you cannot get around): write exactly what failed and what you tried to BLOCKED.md, then stop.
Do not wait silently: a finished task without DONE, or a question not written to QUESTION.md, is never noticed.
```

**Claude's side:**

1. After launching the workers, start one background watcher over all their folders: `oc_wait <folder1> <folder2> ...` (with `run_in_background: true`). It ends the moment any folder gets a `DONE`, `QUESTION.md` or `BLOCKED.md`, and prints which one and what it says. Claude is notified when it ends.
2. When it ends: for `DONE`, read `result.md` and check the claims; for a question, answer it with `oc_say <Terminal window id of that worker's tab> <folder> "<answer>"` (it types the answer into the worker's screen and archives the question); for `BLOCKED`, decide whether to fix the cause, rewrite the task, or tell the user.
3. Start the watcher again, leaving out the folders already finished, until every worker has reported.
4. The window id of each worker's tab is printed by `oc_tui` ("new tab (window number N)"); write it down next to the worker's folder.

The user can also type into any worker's screen directly at any time.

## Visible mode (macOS; the default when the user says to use GLM or DeepSeek with OpenCode, including several subagents at once)

Launch every worker with the interactive-screen launcher, one call per worker:

```
~/bin/oc_tui opencode/glm-5.3-flash-free "<the full prompt for this worker>"
```

It opens the FULL interactive OpenCode screen (its thinking, replies, tool calls, and a box at the bottom where the user can type to it) and starts the task by itself, all permissions on. The first one opens a fresh Terminal window; every later one opens as a NEW TAB in that same window (via ~/bin/oc_tab), so six subagents = one window with six tabs, never six windows. Launch them one after another with a few seconds between calls (the tab is opened through the Terminal menu). Prefer this over hidden background `opencode run` jobs whenever the user wants to watch the subagents.

Each worker writes its answer to its own result file (give it an absolute path in its own folder under ~/.opencode_work/<job>_<n>/). The screens stay open after the task, so do not wait for the process to end: watch for the result files (a background shell: `until [ all result files exist ]; do sleep 60; done`), and if a worker stalls, read its screen with osascript by its tty (`ps -axo pid=,tty=,command= | grep "opencode $HOME/.opencode_work"`).

`~/bin/oc_watch <model> "<prompt>"` is the older launcher: plain `opencode run` output in one reusable window, one task at a time. Use it only for a single quick run.

## Hard rules learned the hard way

- NEVER run OpenCode with the home folder as its directory (`--dir ~` or `cd ~`) if the home folder is a git repo: OpenCode scans it and hangs with no output. Always run from a small folder such as `~/.opencode_work`. OpenCode can still read any file by its full path.
- Non-interactive runs block forever on a permission prompt. Either pass `--auto`, or set permissions to "allow" in `~/.config/opencode/opencode.json` (the installer offers this).
