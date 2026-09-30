## Cross-Model Collaboration (Codex)

Claude Code can delegate work to OpenAI Codex via `~/.claude/bin/codex-bridge.sh`.
Both run on subscriptions — no API keys. The bridge script unsets `OPENAI_API_KEY`
so Codex never accidentally uses your project's API key for billing.

**Commands:**

| Command | Purpose |
|---------|---------|
| `/collab <task>` | Full collaboration: think, build, or debug with Codex |
| `/collab-review` | Quick second opinion from Codex on current changes |
| `/collab-init` | Choose the model (or panel of models) for each stage |

**Stage map:** the `plan`, `build`, `review` and `test` stages each read their model
from `./.collab/models.conf`, then `~/.claude/collab/models.conf`, then built-in
defaults. `plan` and `review` can be a panel of several models that discuss together;
the first model listed is the lead. Show the map with `~/.claude/bin/collab-config.sh show`.

**How it works:** Claude calls `codex exec` via bash. Codex's response streams
directly into Claude's context. Claude reads it, reasons about it, synthesizes.
No tmux, no file polling, no third-party tools. Build tasks run asynchronously
in the background so the user can keep talking to Claude while Codex works.

**Bridge modes:**
- `codex-bridge.sh think "prompt"` — read-only, for debate and review (sync)
- `codex-bridge.sh build "prompt"` — workspace-write, for implementation (async)
- `codex-bridge.sh build "prompt" path/to/spec.md` — build from spec file (async)
- Prefix a call with `COLLAB_STAGE=<plan|build|review|test>` to use that stage's model

**Build specs** go in `.collab/specs/`. **Reports** go in `.collab/reports/`.

**Rules:**
- Never assign overlapping files to both Claude subagents and Codex
- Always run your test suite after Codex builds — never trust the self-report
- Keep Codex prompts concise (500 words max) — it has no session memory
- Synthesize Codex output for the user, don't relay it raw
- Compact context before starting a collab workflow
- Break large builds into 2-3 small focused Codex calls (max 3 files each)
