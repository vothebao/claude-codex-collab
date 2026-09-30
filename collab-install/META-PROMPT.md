# Install the Collab System

I've placed the installation files in `collab-install/`. Do everything below in order without stopping.

The scripts and slash commands install at user level (`~/.claude`), because the commands call the scripts as `~/.claude/bin/...`. Only the `.collab/` working directory belongs to this project.

## Install

1. `mkdir -p .collab/specs .collab/reports ~/.claude/bin ~/.claude/commands`
2. Read `collab-install/codex-bridge.sh` and save it to `~/.claude/bin/codex-bridge.sh` — preserve the content exactly as-is, especially bash variables. Then `chmod +x ~/.claude/bin/codex-bridge.sh`
3. Read `collab-install/collab-config.sh` and save it to `~/.claude/bin/collab-config.sh` — preserve the content exactly as-is. Then `chmod +x ~/.claude/bin/collab-config.sh`
4. Read `collab-install/collab.md` and save it to `~/.claude/commands/collab.md`
5. Read `collab-install/collab-init.md` and save it to `~/.claude/commands/collab-init.md`
6. Read `collab-install/collab-review.md` and save it to `~/.claude/commands/collab-review.md`
7. Read `collab-install/CLAUDE-md-addition.md` and insert its content into `CLAUDE.md` before the last section
8. Add `.collab/` to `.gitignore` if not already there

## Verify

Run these and report results:
1. `ls -la ~/.claude/bin/codex-bridge.sh ~/.claude/bin/collab-config.sh` — both must be executable
2. `head -1 ~/.claude/commands/collab.md` — must show "/collab"
3. `head -1 ~/.claude/commands/collab-init.md` — must show "/collab-init"
4. `head -1 ~/.claude/commands/collab-review.md` — must show "/collab-review"
5. `grep "Cross-Model Collaboration" CLAUDE.md` — must find the section
6. `~/.claude/bin/collab-config.sh show` — must print the four stages `plan`, `build`, `review`, `test`, each with a model
7. `~/.claude/bin/codex-bridge.sh think "Run: echo OPENAI_API_KEY=\$OPENAI_API_KEY — report the exact output"` — API key MUST be empty. If it shows sk-*, STOP.
8. `COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh think "Read README.md, tell me the project name. One line."` — must return the correct name
9. `COLLAB_STAGE=build ~/.claude/bin/codex-bridge.sh build "Create .collab/test.txt containing WORKS"` — then `cat .collab/test.txt` must show WORKS, then `rm .collab/test.txt`

If check 8 or 9 exits with code 3, the `build` stage is assigned to a Claude model in an existing stage map; rerun that check with `CODEX_MODEL=<any Codex slug from collab-config.sh models>` in place of `COLLAB_STAGE=build`.

## Clean up

`rm -rf collab-install/`

## Report

Tell me how many of the 9 checks passed. If all passed: "Collab system installed. /collab, /collab-init and /collab-review are ready. Run /collab-init to choose the model for each stage."
