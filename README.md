# Claude × Codex Collab

**Three models. One orchestrator. Zero API costs.**

A dead-simple system that makes Claude Code and OpenAI Codex CLI work together as a team. Claude Code drives the loop and holds your codebase context; Codex contributes two specialized models — **Astra** for planning and review, **Sol** for implementation and running tests. They debate architecture, delegate implementation, and cross-review code. All running on your existing subscriptions. No API keys. No third-party tools. No MCP servers. No tmux. Just bash, markdown, and slash commands.

```
You → Claude Code (orchestrator + secondary planner)
       ├── Claude subagents (deep codebase work)
       └── codex exec via bash
             ├── Astra (gpt-6-astra) — lead planner + reviewer + test-plan
             └── Sol   (gpt-5.6-sol) — implementation + running tests
```

## Roles

This setup deliberately splits the work by each model's strength:

| Stage | Who | Model |
|---|---|---|
| Orchestration | Claude Code | (drives the loop, writes specs, synthesizes, verifies) |
| Planning | **Astra decides**, Claude assists | `gpt-6-astra` + Claude (secondary) |
| Implementation | **Sol** | `gpt-5.6-sol` |
| Review + test plan | **Astra** | `gpt-6-astra` |
| Running the tests | **Sol** | `gpt-5.6-sol` |
| Final verification | Claude Code | (re-runs tests, never trusts a claim) |

Claude Code stays the orchestrator because it holds your full session context — your codebase, conversation history, project conventions. Codex brings the two model roles. Claude always re-runs tests itself rather than trusting reported results.

## Why this exists

Every developer using AI coding agents hits the same ceiling: **one model, one perspective, one set of blind spots.** Different models are good at different things — planning judgment, fast focused implementation, careful review. But they don't talk to each other.

Until now, your options were:
- Copy-paste between terminals (tedious, breaks flow)
- Third-party orchestration tools (complex setup, another dependency)
- MCP bridges and messaging bots (overengineered for the problem)
- Just pick one and ignore the rest

This system takes a different approach: **Claude Code calls Codex directly via bash.** That's the whole trick. `codex exec` runs headlessly and returns output to stdout. Claude reads it as a regular tool result. No infrastructure. No coordination layer. The filesystem and bash are the only "middleware."

## What it actually does

### Think — models debate your problem

You ask a question. Claude forms a secondary position, then calls Astra to produce the primary plan and challenge it. They go back and forth for up to 2 rounds. **Astra synthesizes and makes the final call**; Claude presents the recommendation.

```
/collab Should we use event-driven architecture or cron-based scheduling for our background jobs?
```

Claude doesn't just relay Codex's response — it **reasons about it**, identifies where they agree, where they diverge, and who has the stronger argument. You get a synthesis neither model would produce alone.

### Build — Astra plans, Sol implements, Astra reviews, Sol tests

Astra makes the final design decision. Claude writes a structured spec. Sol builds it in the background (async — you keep chatting with Claude). Astra then reviews the diff and writes a concrete test plan, Sol runs the tests, and Claude re-runs them independently and reports.

```
/collab Build a rate limiter utility with sliding window algorithm. Include tests.
```

The key insight: **build tasks run asynchronously.** Claude launches Codex in the background and checks on it periodically. You're never staring at a frozen terminal.

### Debug — Competing hypotheses

Claude forms Hypothesis A about a bug. Astra forms Hypothesis B **independently** (Claude deliberately withholds its own hypothesis). If they converge — high confidence. If they diverge — Claude designs a discriminating test and the evidence decides.

```
/collab Users report intermittent 500 errors on the /api/generate endpoint. Debug it.
```

This is the scientific method applied to debugging: independent hypotheses, then experimentation.

## Setup (5 minutes)

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) with an Anthropic subscription
- [Codex CLI](https://github.com/openai/codex) with a ChatGPT subscription (Plus, Pro, or Enterprise)

```bash
# Install Codex CLI if you haven't
npm install -g @openai/codex

# Log in with your ChatGPT account (not an API key)
codex login

# Verify subscription auth
cat ~/.codex/auth.json | grep auth_mode
# Should show: "auth_mode": "chatgpt"
```

### Install

1. Clone this repo or copy the files into your project:

```bash
# Option A: Clone and copy
git clone https://github.com/vothebao/claude-codex-collab.git
mkdir -p your-project/.claude/bin your-project/.claude/commands
cp claude-codex-collab/collab-install/codex-bridge.sh your-project/.claude/bin/
chmod +x your-project/.claude/bin/codex-bridge.sh
cp claude-codex-collab/collab-install/collab.md your-project/.claude/commands/
cp claude-codex-collab/collab-install/collab-review.md your-project/.claude/commands/
mkdir -p your-project/.collab/specs your-project/.collab/reports

# Option B: Use the meta-prompt (recommended)
# Copy the collab-install/ folder into your project root
# Then paste the contents of META-PROMPT.md into Claude Code
# Claude Code will install everything and run verification tests
```

2. Add the collab section to your project's `CLAUDE.md` (see [collab-install/CLAUDE-md-addition.md](collab-install/CLAUDE-md-addition.md))

3. Add `.collab/` to your `.gitignore`

4. **If your project has an `OPENAI_API_KEY` in the environment** (for embeddings, moderation, etc.), the bridge script already handles this — it unsets the key before calling Codex so your API account is never billed. But verify:

```bash
.claude/bin/codex-bridge.sh think "Run: echo OPENAI_API_KEY=\$OPENAI_API_KEY — report the output"
```

The key should be empty.

### Verify

Run in Claude Code:

```
/collab What are the trade-offs between monorepo and polyrepo for a TypeScript project?
```

If Claude debates with Codex and presents a synthesis — you're done.

## How it works under the hood

### The bridge script

`.claude/bin/codex-bridge.sh` does four things:
1. Unsets `OPENAI_API_KEY` (forces Codex to use subscription auth)
2. Disables OpenTelemetry (works around a known Codex CLI crash)
3. Selects the model per-call from the `CODEX_MODEL` env var (empty → your config default)
4. Calls `codex exec` for each mode

Think mode (read-only intent, for plan / review / debate) and build mode (workspace-write, for implementation and running commands) both call `codex exec`. In sandboxed/containerized hosts the script bypasses Codex's own sandbox because the outer container is already the security boundary.

### Selecting the model

The bridge honors a `CODEX_MODEL` environment variable and injects `-m` for you:

```bash
# Astra for planning / review / test-plan
CODEX_MODEL=gpt-6-astra  .claude/bin/codex-bridge.sh think "plan / review this"

# Sol for implementation / running tests
CODEX_MODEL=gpt-5.6-sol  .claude/bin/codex-bridge.sh build "implement / run tests"
```

If `CODEX_MODEL` is unset, Codex uses whatever default your `~/.codex/config.toml` specifies. The orchestration in `collab.md` sets this per stage automatically.

### The slash commands (markdown files)

`.claude/commands/collab.md` teaches Claude Code the orchestration protocol:
- The active role split (Claude orchestrates; Astra plans + reviews; Sol builds + tests)
- How to detect think/build/debug mode from your request
- How to format prompts to Codex (concise, structured, stateless)
- How to run builds asynchronously (background process + PID polling)
- How to synthesize cross-model output (summarize, don't relay)
- Safety rules (never overlap files, always verify tests, compact context)

`.claude/commands/collab-review.md` is a lighter version for quick code reviews.

### Async build pattern

```bash
# Launch in background
CODEX_MODEL=gpt-5.6-sol .claude/bin/codex-bridge.sh build "prompt" > .collab/codex-output.txt 2>&1 &
CODEX_PID=$!

# Claude stays interactive — you keep chatting

# Check periodically
kill -0 $CODEX_PID 2>/dev/null && echo "RUNNING" || echo "DONE"

# When done, read results
cat .collab/codex-output.txt
```

Claude estimates the wait time based on task complexity and checks automatically. You never manage this yourself.

## Customization

### Change the model roles

Model ids are chosen per-call via `CODEX_MODEL` (see above). To use different models, edit the values the orchestration passes — for example swap `gpt-6-astra` / `gpt-5.6-sol` for whatever your subscription provides, or pin a reasoning model for harder planning:

```bash
CODEX_MODEL=<your-planning-model>  .claude/bin/codex-bridge.sh think "..."
CODEX_MODEL=<your-build-model>     .claude/bin/codex-bridge.sh build "..."
```

The active role split lives in the **ACTIVE ROLE OVERRIDE** block at the top of `collab.md` — edit that block to reassign who plans, implements, reviews, and tests.

### Adapt for your project

The slash commands reference generic conventions. Edit `.claude/commands/collab.md` to include your project's:
- Test command (replace `npm test` with yours; e.g. `pytest`)
- Interpreter path if the Codex build shell can't find it (e.g. use an absolute `python` path)
- Framework rules (React, Vue, Rails, etc.)
- Directory conventions
- Code style requirements

### Add more collaboration patterns

The system is just slash commands + a bash script. Add your own patterns by creating new `.claude/commands/collab-*.md` files. Ideas:
- `/collab-refactor` — propose competing refactoring approaches
- `/collab-test` — Sol writes tests for code just built
- `/collab-doc` — Codex documents code with fresh eyes

## Design decisions

**Why Claude orchestrates, not a neutral third party:** Claude holds your full session context — your codebase, your conversation history, your project conventions. That context is why it coordinates and does final verification, even when Codex does the planning and building.

**Why Astra plans and reviews, Sol implements:** The roles map to each model's strength — Astra for planning judgment and review, Sol for fast, focused execution. Splitting them beats using one model for everything.

**Why `codex exec` and not the Codex SDK:** The SDK requires Node.js thread management. `codex exec` is one bash command. Claude Code already runs bash. Zero new infrastructure.

**Why async for build but sync for think:** Think mode needs immediate response for debate flow (15-30 seconds). Build mode can take minutes — blocking the terminal kills the UX. Background process + polling gives you both speed and interactivity.

**Why max 2 debate rounds:** Diminishing returns. If two rounds don't converge, the disagreement is usually fundamental and requires a human decision, not more AI debate.

**Why specs for build tasks:** Codex has no memory of your session. Without a structured spec (files to create, files NOT to touch, interfaces, constraints), Codex will make assumptions. Specs eliminate ambiguity.

**Why Claude re-runs tests itself:** A model reporting "all tests pass" is not evidence. The orchestrator re-runs them and reads the real output before reporting success.

**Why `unset OPENAI_API_KEY`:** Many projects have an OpenAI API key in the environment for embeddings or other services. Without unsetting it, Codex CLI silently uses the API key instead of subscription auth — and you get billed. The bridge script prevents this.

## What this is NOT

- **Not an agent swarm framework.** It's a few agents and a bash script.
- **Not an MCP server.** No protocol, no transport layer, no discovery.
- **Not a SaaS product.** It's a handful of files you drop into your project.
- **Not model-locked.** Swap any model id via `CODEX_MODEL`; swap Claude or Codex for another CLI agent that can run bash.

## License

MIT — use it, fork it, adapt it, ship it.
