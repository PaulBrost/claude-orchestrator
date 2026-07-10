# Getting Started with Claude Code

The short version of installing and running the Claude Code CLI. Authoritative docs: https://code.claude.com/docs

## Install

**Native installer (recommended — keeps itself updated):**

```bash
# macOS / Linux / WSL
curl -fsSL https://claude.ai/install.sh | bash
```

```powershell
# Windows PowerShell
irm https://claude.ai/install.ps1 | iex
```

Alternatives (manual updates): `brew install --cask claude-code`, `winget install Anthropic.ClaudeCode`, and apt/dnf/apk packages on Linux. On native Windows, install Git for Windows so Claude Code gets a real Bash; under WSL that's not needed.

## First run & login

```bash
claude
```

The first run opens a browser login. You can authenticate with a Claude subscription (Pro/Max/Team/Enterprise) or an Anthropic Console account with API credits. Credentials are stored locally; use `/login` inside a session to re-authenticate or switch accounts.

## The essentials

- `claude` — start an interactive session in the current directory. `claude -c` continues your last session here; `claude "do X"` runs a one-off task.
- **CLAUDE.md** — a file at the project root that loads automatically at session start. Put in it what Claude should always know here: build commands, conventions, gotchas, "always/never" rules. Keep it focused (~200 lines); specific beats vague ("use 2-space indent" works, "format nicely" doesn't).
- **`@imports`** — a line like `@projects.md` inside CLAUDE.md loads that file too (this repo uses that to keep the private project registry out of git). Relative paths resolve from the importing file; wrap a path in backticks to *mention* it without importing. Max import depth is 4. The first time Claude encounters an import you'll be asked to approve it.
- **`/model`** — pick the model (and press `s` to apply to the current session only instead of saving as default).
- **Permission modes** — by default Claude asks before running tools; "don't ask again" saves per-command grants. `plan` mode is read-only exploration; `acceptEdits` auto-approves file edits. See `/permissions`.
- **Settings** — JSON at three levels: `~/.claude/settings.json` (you, all projects), `.claude/settings.json` (shared with the team, in git), `.claude/settings.local.json` (you, this repo, gitignored). More-specific levels win; deny rules always win.

## Useful to know

- `CLAUDE.local.md` next to a CLAUDE.md loads after it and is conventionally gitignored — another way to layer personal notes on shared instructions.
- Nested `CLAUDE.md` files in subdirectories load lazily when Claude works in those directories.
- Claude Code also keeps its own persistent memory per project (separate from CLAUDE.md, under `~/.claude/projects/<project>/memory/`) — it accumulates learnings across sessions automatically.
