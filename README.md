# Claude × Codex Collab

**Three models. One orchestrator. Zero API costs.**

A dead-simple system that makes Claude Code and OpenAI Codex CLI work together as a team. Claude Code drives the loop and holds your codebase context; Codex contributes two specialized models — by default **Astra** for planning and review, **Sol** for implementation and running tests. You pick the model for each stage with `/collab-init`, and the planning and review stages can each be a panel of several models that discuss together. They debate architecture, delegate implementation, and cross-review code. All running on your existing subscriptions. No API keys. No third-party tools. No MCP servers. No tmux. Just bash, markdown, and slash commands.

```
You → Claude Code (orchestrator + secondary planner)
       ├── Claude subagents (deep codebase work)
       └── codex exec via bash
             ├── Astra (gpt-6-astra) — lead planner + reviewer + test-plan
             └── Sol   (gpt-5.6-sol) — implementation + running tests
```

## Roles

This setup deliberately splits the work by each model's strength:

The table shows the default assignment. Every stage's model is configurable; see [Choose the model for each stage](#choose-the-model-for-each-stage-collab-init).

| Stage | Who | Model |
|---|---|---|
| Orchestration | Claude Code | (drives the loop, writes specs, synthesizes, verifies) |
| Planning | **Astra decides**, Claude assists | `gpt-6-astra` + Claude (secondary) |
| Implementation | **Sol** | `gpt-5.6-sol` |
| Review + test plan | **Astra** | `gpt-6-astra` |
| Running the tests | **Sol** | `gpt-5.6-sol` |
| Final verification | Claude Code | (re-runs tests, never trusts a claim) |

Claude Code stays the orchestrator because it holds your full session context — your codebase, conversation history, project conventions. Codex brings the two model roles. Claude always re-runs tests itself rather than trusting reported results.

## Choose the model for each stage (`/collab-init`)

The pipeline has four stages, and each one reads its model from a stage map:

| Stage | Handles | Accepts | Default |
|---|---|---|---|
| `plan` | Primary plan, debate, final planning decision | One model or a panel | `codex:gpt-6-astra` |
| `build` | Implementation | One model | `codex:gpt-5.6-sol` |
| `review` | Diff review + test plan (also `/collab-review`) | One model or a panel | `codex:gpt-6-astra` |
| `test` | Running the test commands from the review | One model | `codex:gpt-5.6-sol` |

Run `/collab-init` in Claude Code to set the map. It lists every model your Codex CLI offers plus the Claude models, and gives you a menu per stage.

- A value is `codex:<slug>` (runs through the bridge) or `claude:<opus|sonnet|haiku|fable>` (runs as a Claude subagent).
- **Panels.** Pick several models for `plan` or `review` and they discuss together: independent positions first, one cross-examination round if they disagree, then the **lead** (the first model in the list) makes the final call.
- `/collab-init plan=claude:opus,codex:gpt-6-astra build=codex:gpt-6-sol` sets stages directly, without the menus.
- `/collab-init --project` saves to `./.collab/models.conf` for the current project only. The default is `~/.claude/collab/models.conf`, which applies everywhere. Lookup order: project file, then global file, then the built-in defaults.

```bash
~/.claude/bin/collab-config.sh show     # the resolved map and where each value comes from
~/.claude/bin/collab-config.sh models   # every selectable model
```

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

1. Clone this repo and copy the files into `~/.claude`. The slash commands call the scripts as `~/.claude/bin/...`, so this is a user-level install that works in every project:

```bash
# Option A: Clone and copy
git clone https://github.com/vothebao/claude-codex-collab.git
mkdir -p ~/.claude/bin ~/.claude/commands
cp claude-codex-collab/collab-install/codex-bridge.sh claude-codex-collab/collab-install/collab-config.sh ~/.claude/bin/
chmod +x ~/.claude/bin/codex-bridge.sh ~/.claude/bin/collab-config.sh
cp claude-codex-collab/collab-install/collab.md claude-codex-collab/collab-install/collab-init.md claude-codex-collab/collab-install/collab-review.md ~/.claude/commands/
mkdir -p your-project/.collab/specs your-project/.collab/reports

# Option B: Use the meta-prompt (recommended)
# Copy the collab-install/ folder into your project root
# Then paste the contents of META-PROMPT.md into Claude Code
# Claude Code will install everything and run verification tests
```

2. Add the collab section to your project's `CLAUDE.md` (see [collab-install/CLAUDE-md-addition.md](collab-install/CLAUDE-md-addition.md))

3. Add `.collab/` to your `.gitignore`

4. Optional: run `/collab-init` to choose the model for each stage. Without it the defaults in the table above apply.

5. **If your project has an `OPENAI_API_KEY` in the environment** (for embeddings, moderation, etc.), the bridge script already handles this — it unsets the key before calling Codex so your API account is never billed. But verify:

```bash
~/.claude/bin/codex-bridge.sh think "Run: echo OPENAI_API_KEY=\$OPENAI_API_KEY — report the output"
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

`~/.claude/bin/codex-bridge.sh` does four things:
1. Unsets `OPENAI_API_KEY` (forces Codex to use subscription auth)
2. Disables OpenTelemetry (works around a known Codex CLI crash)
3. Selects the model per-call: from `CODEX_MODEL` if set, otherwise from the stage map via `COLLAB_STAGE`, otherwise your Codex config default
4. Calls `codex exec` for each mode

Think mode (read-only intent, for plan / review / debate) and build mode (workspace-write, for implementation and running commands) both call `codex exec`. In sandboxed/containerized hosts the script bypasses Codex's own sandbox because the outer container is already the security boundary.

### Selecting the model

The orchestration names the stage, and the bridge looks the model up in the stage map and injects `-m` for you:

```bash
COLLAB_STAGE=plan    ~/.claude/bin/codex-bridge.sh think "plan / debate / decide"
COLLAB_STAGE=build   ~/.claude/bin/codex-bridge.sh build "implement"
COLLAB_STAGE=review  ~/.claude/bin/codex-bridge.sh think "review diff + write test plan"
COLLAB_STAGE=test    ~/.claude/bin/codex-bridge.sh build "run these test commands"
```

Precedence, highest first:

1. `CODEX_MODEL=<slug>` forces a model for one call. This is also how the orchestrator calls one Codex member of a panel.
2. `COLLAB_STAGE=<stage>` resolves the model from the stage map (`~/.claude/bin/collab-config.sh`).
3. With neither set, Codex uses the default in your `~/.codex/config.toml`.

A stage assigned to a Claude model, or to a panel of several models, is not a single Codex call. The bridge refuses it with exit code 3 and prints the members, and the orchestrator runs it as a Claude subagent or through the panel protocol in `collab.md`.

### The slash commands (markdown files)

`~/.claude/commands/collab.md` teaches Claude Code the orchestration protocol:
- The active role split (Claude orchestrates; the `plan`, `build`, `review` and `test` stages go to the models in the stage map)
- The panel protocol for stages with several models
- How to detect think/build/debug mode from your request
- How to format prompts to Codex (concise, structured, stateless)
- How to run builds asynchronously (background process + PID polling)
- How to synthesize cross-model output (summarize, don't relay)
- Safety rules (never overlap files, always verify tests, compact context)

`~/.claude/commands/collab-init.md` is the model picker: it lists every available Codex and Claude model and saves your choice per stage.

`~/.claude/commands/collab-review.md` is a lighter version for quick code reviews. It uses the `review` stage's model.

### Async build pattern

```bash
# Launch in background
COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh build "prompt" > .collab/codex-output.txt 2>&1 &
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

Run `/collab-init` and pick a model, or a panel of models, for each stage. Nothing needs editing by hand; see [Choose the model for each stage](#choose-the-model-for-each-stage-collab-init).

What each stage *does* lives in the **ACTIVE ROLE OVERRIDE** block at the top of `collab.md` — edit that block to change the pipeline itself.

### Adapt for your project

The slash commands reference generic conventions. Edit `~/.claude/commands/collab.md` to include your project's:
- Test command (replace `npm test` with yours; e.g. `pytest`)
- Interpreter path if the Codex build shell can't find it (e.g. use an absolute `python` path)
- Framework rules (React, Vue, Rails, etc.)
- Directory conventions
- Code style requirements

### Add more collaboration patterns

The system is just slash commands + a bash script. Add your own patterns by creating new `~/.claude/commands/collab-*.md` files. Ideas:
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
- **Not model-locked.** Swap any stage's model with `/collab-init`; swap Claude or Codex for another CLI agent that can run bash.

## License

MIT — use it, fork it, adapt it, ship it.
