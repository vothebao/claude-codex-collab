#!/usr/bin/env bash
# codex-bridge.sh — Claude Code → Codex CLI bridge
#
# Usage:
#   codex-bridge.sh think "Your prompt here"
#   codex-bridge.sh build "Your prompt here"
#   codex-bridge.sh build "Implement this spec" .collab/specs/task.md
#   COLLAB_STAGE=review codex-bridge.sh think "Review the diff"
#
# Modes:
#   think — Read-only. Codex reads files but changes nothing.
#           For debate, review, architecture, debugging hypotheses.
#   build — Workspace-write + full-auto. Codex creates/modifies files.
#           For implementation tasks delegated by Claude.
#
# Security:
#   Unsets OPENAI_API_KEY to force subscription auth (chatgpt mode).
#   Your project's API key for embeddings/moderation is NOT used by Codex.

set -euo pipefail

MODE="${1:?Usage: codex-bridge.sh <think|build> \"prompt\" [spec-file]}"
PROMPT="${2:?Usage: codex-bridge.sh <think|build> \"prompt\" [spec-file]}"
SPEC_FILE="${3:-}"

# If a spec file is provided, prepend its contents to the prompt
if [[ -n "$SPEC_FILE" && -f "$SPEC_FILE" ]]; then
  PROMPT="## Build Spec
$(cat "$SPEC_FILE")

## Instructions
${PROMPT}"
fi

# ── Security ──────────────────────────────────────────────
# CRITICAL: Many projects have OPENAI_API_KEY in the environment for
# embeddings and moderation. We MUST unset it so Codex CLI
# falls back to ~/.codex/auth.json (chatgpt subscription).
# This prevents accidental API billing.
unset OPENAI_API_KEY

# Suppress OpenTelemetry crash (known Codex CLI bug)
export OTEL_SDK_DISABLED=true

# ── Sandbox ───────────────────────────────────────────────
# This host runs inside a locked-down container where Codex's default
# bubblewrap (bwrap) sandbox cannot initialize ("Failed to make / slave").
# Codex documents --dangerously-bypass-approvals-and-sandbox for exactly
# this case: environments that are already externally sandboxed. The outer
# container is the security boundary; Codex-run commands have full access
# within it. In 'think' mode the read-only intent is enforced by the prompt.
BYPASS="--dangerously-bypass-approvals-and-sandbox"

# ── Model selection ───────────────────────────────────────
# Precedence, highest first:
#   1. CODEX_MODEL=<slug>                      — force a model for this call
#   2. COLLAB_STAGE=<plan|build|review|test>   — model from the stage map
#      written by /collab-init (see collab-config.sh)
#   3. neither set                             — Codex config.toml default
# A stage mapped to claude:<alias> is not a Codex job; the bridge refuses
# it (exit 3) so the orchestrator runs that stage as a Claude subagent.
# A stage mapped to a panel of several models is refused the same way; the
# orchestrator calls each member itself (CODEX_MODEL=<slug> per codex member).
MODEL_ARGS=()
if [[ -n "${CODEX_MODEL:-}" ]]; then
  MODEL_ARGS=(-m "$CODEX_MODEL")
elif [[ -n "${COLLAB_STAGE:-}" ]]; then
  RESOLVED="$(bash "$(dirname "$0")/collab-config.sh" get "$COLLAB_STAGE")"
  if [[ "$RESOLVED" == *$'\n'* ]]; then
    echo "Error: stage '$COLLAB_STAGE' is a panel of several models (lead first):" >&2
    sed 's/^/  /' <<<"$RESOLVED" >&2
    echo "Call each member separately: CODEX_MODEL=<slug> for codex members, a Claude subagent for claude members." >&2
    exit 3
  fi
  STAGE_PROVIDER="${RESOLVED%% *}"
  STAGE_MODEL="${RESOLVED#* }"
  if [[ "$STAGE_PROVIDER" != "codex" ]]; then
    echo "Error: stage '$COLLAB_STAGE' is assigned to $STAGE_PROVIDER:$STAGE_MODEL, not Codex." >&2
    echo "Run this stage as a Claude subagent (model: $STAGE_MODEL) instead of the bridge." >&2
    exit 3
  fi
  MODEL_ARGS=(-m "$STAGE_MODEL")
fi

# ── Execute ───────────────────────────────────────────────
case "$MODE" in
  think)
    exec codex exec $BYPASS "${MODEL_ARGS[@]}" "$PROMPT"
    ;;
  build)
    # codex CLI 0.154.0 removed --full-auto; sandbox bypassed (see above)
    exec codex exec $BYPASS "${MODEL_ARGS[@]}" "$PROMPT"
    ;;
  *)
    echo "Error: Mode must be 'think' or 'build'. Got: $MODE" >&2
    exit 1
    ;;
esac
