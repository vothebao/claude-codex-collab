# /collab-init — Choose the Models for Each /collab Stage

Set which model handles each stage of the `/collab` pipeline, then stop. Do not start a collaboration task in the same turn.

| Stage | Handles | Accepts | Built-in default |
|---|---|---|---|
| `plan` | Primary plan, debate, final planning decision. Also Think-mode debate and the Debug-mode independent hypothesis. | One model or a panel | `codex:gpt-6-astra` |
| `build` | Implementation | One model | `codex:gpt-5.6-sol` |
| `review` | Diff review + test plan. Also `/collab-review`. | One model or a panel | `codex:gpt-6-astra` |
| `test` | Running the test commands from the review | One model | `codex:gpt-5.6-sol` |

A model value is `codex:<slug>` (runs through the Codex bridge) or `claude:<opus|sonnet|haiku|fable>` (runs as a Claude subagent).

A **panel** is several models on one stage, written as a comma-separated list. The members discuss together; the first one listed is the **lead** and makes the final call.

## Steps

1. Run both commands:
   ```bash
   ~/.claude/bin/collab-config.sh show
   ~/.claude/bin/collab-config.sh models
   ```
2. If the arguments contain `stage=value` pairs (e.g. `/collab-init plan=codex:gpt-6-astra,claude:opus build=codex:gpt-6.1-sol`), skip to step 5 with those pairs as written. The first model in a list is the lead.
3. Let the user pick from menus, one AskUserQuestion call per stage, in the order `plan`, `build`, `review`, `test`. Every model in the `models` output is offered for every stage; never a shortlist.
   - Before the first menu, print the full `models` table once as text (number, value, full model name, notes) and the current map, so every model is visible at a glance. Say in one line that each stage's menu spreads the same models over tabs because a menu page holds four options.
   - A question holds at most four options, so each call has one question per group: Codex models in `models` order, four per question, then the Claude models in their own question. With 8 Codex + 4 Claude models that is three questions with headers `Codex 1/2`, `Codex 2/2`, `Claude`. Every group needs two to four options; if a group would hold one model, move one over from the previous group. If a stage needs more than four questions, continue it in a second call.
   - Every option label is the **full model name** from the `models` output (e.g. "GPT-6-Astra", "Claude Opus 5.5"), never the bare alias, with " (current)" appended when the model is in the stage's current value. The description is the `provider:model` value followed by the notes.
   - Every question names the stage in its text (e.g. "Plan stage — Codex models") and sets `multiSelect: true`, so a group can be left empty.
   - `plan` and `review`: the question text says that picking several models makes them discuss together. Any number of picks across the groups is valid, as long as there is at least one.
   - `build` and `test`: the question text says to pick exactly one model across all tabs. If the answer has zero or several, say so and show that stage's menu again.
   - Map each picked name back to its `provider:model` value from the table.
4. For each of Plan and Review where the user picked two or more models, ask which one leads, as a fourth question in the next stage's call or in one more AskUserQuestion call after the last stage (headers `Plan lead`, `Review lead`; single-select; options are the picked models by full name, or the first four if more were picked). Put the lead first in that stage's list. If only one model was picked, there is nothing to ask.
5. Save. Global is the default; add `--project` only when the arguments include `--project`, which writes `./.collab/models.conf` and applies to this project only. Pass only the stages the user set:
   ```bash
   ~/.claude/bin/collab-config.sh set [--project] plan=<lead>[,<member>...] build=<value> review=<lead>[,<member>...] test=<value>
   ```
6. Show the resulting map with full model names, naming the lead of each panel. If every member of `plan` or of `review` is a Claude model, say once that the stage is then Claude-only and no longer a cross-model check.

Lookup order per stage: `./.collab/models.conf` → `~/.claude/collab/models.conf` → built-in default. No config file is required; without one the defaults apply.

$ARGUMENTS
