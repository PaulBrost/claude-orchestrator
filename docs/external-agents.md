# External Agent CLIs — Per-Project LLM Providers

Some projects come with rules about which AI provider may touch them — an employer that requires their GitHub Copilot seat for work code, a client with a provider allowlist, or just billing separation. The orchestrator supports this with a per-project `Agent:` field in the registry: Claude stays the coordinator, but code changes in those projects are executed by the named external CLI instead of Claude sub-agents.

## How it works

1. In `projects.md`, add an `**Agent:**` field to the project entry:

   ```
   ### work-project
   - **Path:** ~/work/project
   - **Agent:** copilot
   ...
   ```

2. When the orchestrator delegates work in that project, it shells out to the CLI non-interactively (in the project directory) rather than spawning a Claude sub-agent. The delegation discipline is unchanged — precise task, acceptance criteria, verification steps, commit conventions — only the executor differs.

3. Claude reviews the result and coordinates anything cross-project, exactly as with its own sub-agents.

## Standard vs. strict mode

The right mode depends on what the provider rule actually says:

- **`Agent: copilot` (standard)** — "our provider does the work by default." The external CLI is the default executor for project tasks; Claude may read the project freely, review diffs for verification, and write directly when the user says so or for orchestrator-driven housekeeping. It's a routing preference, not an isolation rule.
- **`Agent: copilot-strict` (strict)** — "project code must not pass through other LLMs at all." Claude dispatches the task and relays the CLI's report back, but never opens the project's files or diffs. Verification is delegated to the same CLI. This trades review quality for compliance — Claude can only be as confident as the CLI's own report.

If you're unsure which your policy requires, ask whoever owns the policy — the difference is exactly whether a non-approved model may *read* the code, not just write it.

## GitHub Copilot CLI specifics

Install and authenticate (uses your GitHub account / Copilot seat):

```bash
npm install -g @github/copilot
copilot   # first run walks through login; 'copilot update' to update
```

Non-interactive invocation the orchestrator uses:

```bash
cd ~/work/project
copilot -p "the full task prompt" --allow-all-tools
```

Useful flags and behaviors:

- `--allow-all-tools` is required for non-interactive mode (no permission prompts). Granular alternatives: `--allow-tool`, `--allow-all-paths`, `--allow-all-urls`, or `--allow-all` for everything.
- `--add-dir <path>` grants file access outside the working directory (e.g., a shared library the task references).
- Each run prints a footer with credits/token usage and a `Resume: copilot --resume=<session-id>` line — **capture the session id**: follow-up instructions can continue the same session with its context intact (`copilot --resume=<id> -p "follow-up"`), mirroring how Claude sub-agents are reused.
- `--model <name>` exists but is best left at the provider's default unless the user asks.
- Long tasks: run in the background and collect output when done.
- Copilot reads `AGENTS.md` files for project instructions (its analog of `CLAUDE.md`) — keep provider-specific project guidance there.

## Other agent CLIs

The same pattern works for any coding agent with a headless mode (OpenAI Codex CLI, Gemini CLI, etc.): set the `Agent:` field to the CLI name, and document the non-interactive invocation here so the orchestrator knows the flags. The requirements are just: a prompt flag, a way to pre-approve tool use, and text output.

## Permissions note

To avoid approving every dispatch, allowlist the CLI in the orchestrator's `.claude/settings.local.json` (personal) — e.g. `"Bash(copilot *)"`. Keep it out of the shared `settings.json` unless everyone using the repo wants it.
