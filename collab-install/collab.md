# /collab — Cross-Model Collaboration

> ## ⭐ ACTIVE ROLE OVERRIDE (2026-09-15) — READ FIRST, TAKES PRECEDENCE
>
> The default write-up below assumes "Claude plans → Codex builds → Claude reviews."
> **That is superseded by the roles in this box.** Wherever the two conflict, this box wins.
>
> **Roles**
> - **Claude = orchestrator / điều phối.** Drives the loop, calls Codex via the bridge, writes specs, synthesizes Codex output, reports to the user, and spot-verifies results. Claude does NOT do the primary implementation.
> - **Planning = joint debate, the `plan` lead decides.** The `plan`-stage model(s) and Claude (the orchestrator) produce plans and debate (≤2 rounds). Claude's plan is the *secondary/advisory* voice. **The `plan` lead synthesizes and makes the final planning decision.**
> - **Implementation = the `build` model** via `build` mode.
> - **Review + test-plan = the `review` model(s)** via `think` mode; the `review` lead merges the findings into one test plan.
> - **Running the tests = the `test` model** via `build` mode — executes the exact test commands the review specified.
>
> **Model selection.** Each stage's model comes from the stage map, chosen with `/collab-init` (see "Stage map" below). `plan` and `review` may each be a panel of several models that discuss together. Never hardcode a model name — pass the stage and the bridge resolves it:
> ```bash
> COLLAB_STAGE=plan    ~/.claude/bin/codex-bridge.sh think "plan / debate / decide"
> COLLAB_STAGE=build   ~/.claude/bin/codex-bridge.sh build "implement"
> COLLAB_STAGE=review  ~/.claude/bin/codex-bridge.sh think "review diff + write test plan"
> COLLAB_STAGE=test    ~/.claude/bin/codex-bridge.sh build "run these test commands"
> ```
> `CODEX_MODEL=<slug>` forces a model for a single call and wins over `COLLAB_STAGE`; it is how you call one member of a panel.
>
> **Build-task flow (overrides the MODE: Build section below)**
> 1. Claude drafts a short *secondary* plan.
> 2. `COLLAB_STAGE=plan … think` → the `plan` model produces the *primary* plan; the two debate ≤2 rounds; **the `plan` model makes the final call.** With a `plan` panel, run the panel protocol instead; the lead makes the final call.
> 3. Claude writes the agreed spec to `.collab/specs/<task>.md`.
> 4. `COLLAB_STAGE=build … build` → the `build` model implements per spec (async pattern below).
> 5. `COLLAB_STAGE=review … think` → the `review` model reviews the diff and writes a concrete test plan. With a `review` panel, run the panel protocol instead; the lead writes the merged test plan.
> 6. `COLLAB_STAGE=test … build` → the `test` model runs the test commands from the review.
> 7. Claude synthesizes results, spot-verifies, and reports.
>
> Everything below (sync/async mechanics, spec format, context-management, critical rules) still applies **except** the fixed "who plans / who reviews" assignment, which this box replaces.

## Stage map — which model handles each stage

The map is set with `/collab-init` and read with `~/.claude/bin/collab-config.sh show`.

| Stage | Handles | Accepts |
|---|---|---|
| `plan` | Primary plan, debate, final planning decision. Also Think-mode debate and the Debug-mode independent hypothesis. | One model or a panel |
| `build` | Implementation | One model |
| `review` | Diff review + test plan. Also `/collab-review`. | One model or a panel |
| `test` | Running the test commands from the review | One model |

A model value is `codex:<slug>` or `claude:<opus|sonnet|haiku|fable>`. How you run a stage depends on what the map holds for it:

| Map holds | How to run the stage |
|---|---|
| One `codex:` model | `COLLAB_STAGE=<stage> ~/.claude/bin/codex-bridge.sh <mode> "<prompt>"` |
| One `claude:` model | Agent tool with `model: <alias>` and the same prompt or spec you would have sent to Codex. For `plan` and `review`, tell the subagent it is read-only and must not modify files. |
| A panel (several models, `plan` and `review` only) | Panel protocol below |

The bridge refuses a `claude:` stage and a panel stage with exit code 3 and prints the members, so a wrong call fails loudly instead of using the wrong model.

### Panel protocol (several models discuss together)

`~/.claude/bin/collab-config.sh get <stage>` prints one `<provider> <model>` line per member, lead first.

1. **Round 1 — independent positions.** Send every member the same prompt in parallel (one tool call per member in the same message). No member sees another member's answer in this round.
   - `codex` member: `CODEX_MODEL=<slug> ~/.claude/bin/codex-bridge.sh think "<prompt>"`
   - `claude` member: Agent tool with `model: <alias>`, read-only
   - In the `plan` stage, your own secondary plan is one more position on the table.
2. **Round 2 — cross-examination.** Skip it when the round-1 positions already agree. Otherwise send each member your concise, model-attributed summary of the other members' positions and ask: "Where do you now agree? Where do you still disagree, and why? State your final position."
3. **Decision — the lead.** Send the lead every member's final position. The lead writes the single outcome of the stage: the final plan (`plan`), or the merged findings list plus one concrete test plan (`review`). The lead lists any point the panel could not settle as open, and you surface those to the user.

Cap: two rounds plus the decision call. Summarize each member's output before passing it on; never forward raw output between members.

In Debug mode with a `plan` panel, step 3 of that mode collects one independent hypothesis per member, all without seeing yours.

---

You are now acting as **orchestrator** (see role box above). Before the first stage call, run `~/.claude/bin/collab-config.sh show` so you know which model handles each stage, and name that model when you announce a call. You have two engineers:

1. **Claude Engineer** — your native subagents. Use for tasks requiring deep codebase knowledge or domain-specific work, and for any stage the map assigns to `claude:<alias>`. Per the override, Claude is the *coordinator + secondary planner*, not the primary implementer or reviewer.
2. **Codex Engineer** — invoked via bash: `COLLAB_STAGE=<stage> ~/.claude/bin/codex-bridge.sh <mode> "<prompt>"`. The stage picks the model from the map. Use for planning, implementation, review, and test execution.

## How to call Codex

Every call names its stage. Think-mode debate and the Debug-mode hypothesis use `plan`; reviews use `review`. When that stage is a panel, follow the panel protocol above.

```bash
# Thinking, debate, review (read-only — Codex cannot modify files):
COLLAB_STAGE=plan ~/.claude/bin/codex-bridge.sh think "Your prompt here"

# Building (workspace-write — Codex can create/modify files and run commands):
COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh build "Your prompt here"

# Building from a spec file:
COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh build "Implement this spec exactly. Run npm test when done." .collab/specs/task-name.md
```

The bridge script unsets OPENAI_API_KEY automatically so Codex uses subscription auth, not your project's API key. Output streams directly into your bash tool result — read it and reason about it.

## Sync vs async execution

**Think mode → always synchronous.** Run the command directly. It takes 15-30 seconds and you need the response immediately for debate flow.

**Build mode → always asynchronous.** Run Codex in the background so the user can keep talking to you:

**Launch (non-blocking):**
```bash
COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh build "prompt" > .collab/codex-output.txt 2>&1 &
CODEX_PID=$!
echo "Codex PID: $CODEX_PID"
```

Tell the user: "Codex is building in the background. I'll check on it in [estimated time]. You can keep talking to me."

**Estimate wait time by task complexity:**
- Single file creation/edit → check after 30 seconds
- 2-3 files with tests → check after 90 seconds
- Large multi-file implementation → check after 3 minutes

**Check if done:**
```bash
kill -0 <PID> 2>/dev/null && echo "RUNNING" || echo "DONE"
```

- If RUNNING → tell user "Still working, I'll check again in [time]." Check again.
- If DONE → read output: `cat .collab/codex-output.txt`, then review (git diff, npm test).
- Maximum 3 check cycles. If still running, tell the user and offer to keep waiting or abandon.

**After reading output:** `rm -f .collab/codex-output.txt`

**For spec-based builds:**
```bash
COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh build "Implement this spec exactly. Run npm test when done." .collab/specs/task-name.md > .collab/codex-output.txt 2>&1 &
CODEX_PID=$!
echo "Codex PID: $CODEX_PID"
```

## Detect the mode from the user's request

---

### MODE: Think (planning, architecture, debate)

Use when the user wants ideas challenged, a design explored, or competing approaches evaluated.

**Workflow:**

1. **Analyze** the problem. Read relevant files. Form your initial position with concrete reasoning.
2. **Challenge via Codex (sync).** Run `COLLAB_STAGE=plan` codex-bridge.sh think with:
   - A clear problem statement with relevant context (file paths, current behavior, constraints)
   - Your position and reasoning
   - Explicit ask: "Challenge my assumptions. Where am I wrong? What am I missing?"
3. **Synthesize Round 1.** Read Codex's response. Identify:
   - Convergence (agreements)
   - Divergence (disagreements)
   - New perspectives Codex introduced
4. **Round 2 (if divergence exists).** Run `COLLAB_STAGE=plan` codex-bridge.sh think again with:
   - The specific disagreements
   - Codex's argument (quoted concisely)
   - Your counter-argument
   - Ask: "Make your strongest case or concede. Be specific."
5. **Present synthesis to user:**
   - What both models agree on
   - Where they diverged and who had the stronger argument
   - Your final recommendation with reasoning
   - Concrete next steps

**Cap at 2 rounds.** If unresolved, present the open question for human decision.

---

### MODE: Build (Claude designs, Codex implements, Claude reviews)

Use when the user wants something built and you want to delegate implementation.

**Workflow:**

1. **Plan.** Analyze the codebase. Decide the split:
   - What YOU build (via subagents) — deep codebase context required
   - What CODEX builds — isolated, well-specifiable modules
   - If no clean split exists, do it sequentially: Codex builds, you review and refine
2. **Write the spec.** Save to `.collab/specs/<task-name>.md` containing:
   - **Objective:** 1-2 sentences on what and why
   - **Files to create:** Full paths and purpose
   - **Files to modify:** Full paths and what changes
   - **Files DO NOT touch:** Explicit exclusion list
   - **Interfaces:** TypeScript types, function signatures, expected behavior
   - **Constraints:** Frameworks, libraries, existing patterns to follow
   - **Verification:** npm test must pass, plus any additional checks
3. **Snapshot.** Note current HEAD: `git rev-parse HEAD`
4. **Delegate (async).** Launch Codex in the background using the async pattern above.
5. **While waiting.** Tell the user what Codex is working on. Answer questions, discuss the plan, or work on your own portion via subagents.
6. **Review when done.** Check PID, read output, then:
   - `git diff` to see every change
   - `npm test` — run it yourself, never trust Codex's claim
   - Check for files modified outside the spec (reject if found)
   - Review code quality
7. **Fix loop (max 1 round).** If issues:
   - Small fixes → do them yourself directly
   - Significant issues → launch another async Codex call with specific fix instructions
8. **Report to user.** What was built, decisions made, test results.

**NEVER assign overlapping files to both engineers.**
**ALWAYS run npm test yourself after Codex builds.**

---

### MODE: Debug (competing hypotheses)

Use when the user reports a bug and wants multiple angles of investigation.

**Workflow:**

1. **Gather evidence.** Read errors, logs, relevant code. Reproduce if possible.
2. **Form Hypothesis A.** Your root cause analysis with reasoning.
3. **Get Hypothesis B (sync).** Run `COLLAB_STAGE=plan` codex-bridge.sh think with:
   - Bug symptoms (error messages, unexpected behavior)
   - Relevant file paths and code context
   - "Form your own independent hypothesis about the root cause. Reason from the evidence."
   - Do NOT share your hypothesis — you want independent thinking
4. **Compare.** If hypotheses converge → high confidence, fix it. If they diverge:
   - Design a discriminating test that confirms one and refutes the other
   - Run the test
   - Evidence decides the winner
5. **Fix.** Implement based on the winning hypothesis. Run npm test.
6. **Report.** Both hypotheses, what evidence resolved it, what was fixed.

---

## Context management during collaboration

After EVERY codex-bridge.sh call:
- Read the full Codex response for your own reasoning.
- Then mentally discard the raw output — do NOT reference it verbatim again.
- Write a concise summary (3-5 bullet points max) of what Codex said or did.
- Use only that summary when reporting to the user or making further decisions.
- Before starting a second collab round, consider whether you need to compact.
- If the conversation already has 3+ Codex call outputs in context, compact before the next call.

## Critical rules

- **Concise Codex prompts.** Every call is stateless. Include necessary context but keep it tight — 500 words max for think, spec files for build.
- **Synthesize, don't relay.** Never paste Codex's raw output to the user. Read it, reason, present your synthesis.
- **Compact before collab.** If conversation is long, compact context before starting. You need room for Codex responses.
- **Project conventions apply.** Follow the coding standards defined in your CLAUDE.md. All tests must pass.
- **Git hygiene.** Commit or stash before delegating build tasks. Review diffs after.
- **Announce your actions.** Before calling Codex, tell the user: "I'm asking Codex to [think about X / build Y / investigate Z]."
- **Never overlap files.** If both you and Codex need the same file, do it sequentially — never in parallel. Specs must include a DO NOT TOUCH list.
- **Break up large builds.** Prefer 2-3 small focused Codex calls over one monolithic build. Each call should touch at most 3 files.

## Examples

"Should we use event-driven architecture or cron-based scheduling for background jobs?"
→ Think mode. Sync. Form position, challenge via Codex, synthesize.

"Build a rate limiter middleware with sliding window algorithm. Include tests."
→ Build mode. Async. Write spec, delegate to Codex in background, chat with user, review when done.

"Users report 500 errors on POST /api/users when email contains a + character."
→ Debug mode. Sync think. Hypotheses, discriminating test, fix.

"Plan the new notification system architecture, then build it."
→ Think first (sync debate), then Build (async delegation).

"Change which model does the review" / "add Opus to the planning debate"
→ Not a collab task. Point the user to `/collab-init`.

$ARGUMENTS
