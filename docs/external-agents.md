# External Agent CLIs — Per-Project LLM Providers

> **Status: not in use as of 2026-08-28.** Every project in the registry was moved to Claude sub-agents, so no entry currently carries an `**Agent:**` field. This document is kept for two reasons: re-enabling the mechanism is a one-line registry edit if a provider policy ever requires it, and the [acceptance-criteria section](#writing-acceptance-criteria-for-a-copilot-dispatch) describes failure modes worth writing into *any* delegation prompt, Claude sub-agents included.

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
- **`--add-dir <path>` is REQUIRED for any path outside the working directory — including the orchestrator's own `standards/` files. `--allow-all-tools` does NOT grant it.** Verified 2026-08-28 from `/mnt/d/ETS/PIAAC/PIAAC-Portal`: a dispatch handed the absolute path `/mnt/h/claude-orchestrator/standards/documentation.md` failed with `Permission denied and could not request permission from user`, and *still produced a confident, well-formed answer* — it reported the failure only because the prompt asked it to. The identical dispatch with `--add-dir /mnt/h/claude-orchestrator/standards` read the file fine. **A standard passed by path alone silently never arrives**, and the dispatch reports success on everything else it was asked to do. Either pass `--add-dir` for the standards directory, or inline the standard's text into the prompt.
- Each run prints a footer with credits/token usage and a `Resume: copilot --resume=<session-id>` line — **capture the session id**: follow-up instructions can continue the same session with its context intact (`copilot --resume=<id> -p "follow-up"`), mirroring how Claude sub-agents are reused.
- `--model <name>` exists but is best left at the provider's default unless the user asks.
- Long tasks: run in the background and collect output when done. **Use the harness's own backgrounding, not `nohup … &`.** A `nohup`'d dispatch reports "completed" when the *shell* exits, not when Copilot exits — a dispatch believed dead kept running for half an hour, editing the same files the orchestrating agent was editing. If you must background it, confirm the process is actually gone before touching its files.
- **Copilot cannot launch a browser from inside its Snap sandbox**, so any task whose acceptance criteria include real-browser verification has to be verified by us after the dispatch returns. Write the criteria so Copilot can prove everything else, and keep the browser step on our side.
- **The Snap sandbox also cannot run Windows binaries via WSL interop — which breaks git credential helpers AND any build that shells out to `cmd.exe`.** Confirmed twice on the same pds-builder task (2026-08-15): first its `git pull` died on the Windows credential manager, then — with pulls shimmed out — the build died at `cmd.exe: command not found` (the builder drives Windows-side node for the Electron app). A build whose script calls `cmd.exe` is structurally un-delegatable to Copilot on this machine; route the execution to the orchestrator and keep Copilot for the code/config work around it. On a WSL machine whose git `credential.helper` is the Windows Credential Manager (`git-credential-manager-core.exe`), any authenticated `git pull`/`clone` inside a Copilot dispatch dies with `fatal: could not read Username for '<host>': terminal prompts disabled`, even though the same command works in every interactive shell and in the orchestrator's own Bash. Found 2026-08-14 when a pds-builder national build failed at the builder's first `git pull` against the ETS Gitea. Route steps needing authenticated git to the orchestrator (run the build/fetch ourselves after Copilot's prep), or pre-seed a scoped token in `~/.git-credentials` for the specific host if the dispatch must be self-contained.
- Copilot reads `AGENTS.md` files for project instructions (its analog of `CLAUDE.md`) — keep provider-specific project guidance there.

### Writing acceptance criteria for a Copilot dispatch

Measured across several substantial dispatches, the failure pattern is consistent and actionable: **Copilot implements the described behaviour correctly and misses what the criteria did not enumerate.** It respects file boundaries, reports honestly (including reporting its own gate as correctly red rather than weakening it), and gets the non-obvious parts of a precisely-transcribed spec right. The defects cluster in:

- **empty / absent state** — the "nothing selected" case mapping onto index 0, `{}` grading as a wrong answer rather than unsubmitted
- **adversarial input** — attacker-controlled values reaching a log unfiltered and uncapped
- **unbounded growth** — caches and buckets with no cap, or an off-by-one in the sweep
- **per-call vs per-construction derivation** — state computed once at construction that should be derived per call
- **event/stream volume** — emitting one authoritative record per keystroke rather than per submission

So state those cases *explicitly as acceptance criteria*. Dispatches that name them come back needing far less correction. Review output against the criteria rather than accepting it on trust, and record every rejection with its reason — a pattern of failures on a task class tells you what to stop delegating.

## Other agent CLIs

The same pattern works for any coding agent with a headless mode (OpenAI Codex CLI, Gemini CLI, etc.): set the `Agent:` field to the CLI name, and document the non-interactive invocation here so the orchestrator knows the flags. The requirements are just: a prompt flag, a way to pre-approve tool use, and text output.

## Permissions note

To avoid approving every dispatch, allowlist the CLI in the orchestrator's `.claude/settings.local.json` (personal) — e.g. `"Bash(copilot *)"`. Keep it out of the shared `settings.json` unless everyone using the repo wants it.
