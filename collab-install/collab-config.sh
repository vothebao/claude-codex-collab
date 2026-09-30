#!/usr/bin/env bash
# collab-config.sh — stage → model map for the /collab pipeline
#
# Usage:
#   collab-config.sh show                      Resolved map and where each value comes from
#   collab-config.sh get <stage>               One "<provider> <model>" line per member, lead first
#   collab-config.sh set [--project] stage=provider:model[,provider:model...] [...]
#   collab-config.sh models                    Values selectable in /collab-init
#
# Stages:
#   plan   — primary plan, debate, final planning decision (also Think/Debug mode)
#   build  — implementation
#   review — diff review + test plan (also /collab-review)
#   test   — running the test commands from the review
#
# Values:
#   codex:<slug>    — run through codex-bridge.sh (slug from ~/.codex/models_cache.json)
#   claude:<alias>  — run as a Claude subagent (opus | sonnet | haiku | fable)
#
# plan and review accept a comma-separated panel, e.g.
#   plan=codex:gpt-6-astra,claude:opus
# The members discuss together; the first one listed is the lead and makes
# the final call. build and test take exactly one model.
#
# Lookup order per stage:
#   ./.collab/models.conf  →  ~/.claude/collab/models.conf  →  built-in default

set -euo pipefail

STAGES=(plan build review test)
PANEL_STAGES=(plan review)
CLAUDE_ALIASES=(fable opus sonnet haiku)
# What each alias resolves to today. A snapshot for display only — update it
# when Claude Code moves an alias to a newer model.
declare -A CLAUDE_NAMES=(
  [fable]="Claude Fable 5.1"
  [opus]="Claude Opus 5.5"
  [sonnet]="Claude Sonnet 5.5"
  [haiku]="Claude Haiku 4.5"
)
GLOBAL_CONF="${COLLAB_GLOBAL_CONF:-$HOME/.claude/collab/models.conf}"
PROJECT_CONF="${COLLAB_PROJECT_CONF:-.collab/models.conf}"
CODEX_CACHE="${CODEX_MODELS_CACHE:-$HOME/.codex/models_cache.json}"

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

is_stage() {
  local s
  for s in "${STAGES[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

is_panel_stage() {
  local s
  for s in "${PANEL_STAGES[@]}"; do [[ "$s" == "$1" ]] && return 0; done
  return 1
}

default_for() {
  case "$1" in
    plan|review) echo "codex:gpt-6-astra" ;;
    build|test)  echo "codex:gpt-5.6-sol" ;;
  esac
}

# Last "stage = value" line in a conf file; empty if the file or key is absent.
lookup() {
  local file="$1" stage="$2"
  [[ -f "$file" ]] || return 0
  sed -n "s/^[[:space:]]*${stage}[[:space:]]*=[[:space:]]*\([^[:space:]#]*\).*/\1/p" "$file" | tail -n1
}

# Sets VALUE and SOURCE for a stage.
resolve() {
  local stage="$1"
  VALUE="$(lookup "$PROJECT_CONF" "$stage")"; SOURCE="project ($PROJECT_CONF)"
  if [[ -z "$VALUE" ]]; then
    VALUE="$(lookup "$GLOBAL_CONF" "$stage")"; SOURCE="global ($GLOBAL_CONF)"
  fi
  if [[ -z "$VALUE" ]]; then
    VALUE="$(default_for "$stage")"; SOURCE="built-in default"
  fi
}

# One "slug<TAB>display name<TAB>description" line per Codex model the CLI lists.
codex_models() {
  [[ -f "$CODEX_CACHE" ]] || return 0
  python3 - "$CODEX_CACHE" <<'PY' 2>/dev/null || true
import json, sys
for m in json.load(open(sys.argv[1])).get("models", []):
    if m.get("visibility") == "list":
        print(f"{m['slug']}\t{m.get('display_name', m['slug'])}\t{m.get('description') or ''}")
PY
}

validate_member() {
  local value="$1" provider model a
  [[ "$value" =~ ^(codex|claude):[A-Za-z0-9._-]+$ ]] \
    || { echo "Error: '$value' is not codex:<slug> or claude:<alias>" >&2; exit 2; }
  provider="${value%%:*}"; model="${value#*:}"
  if [[ "$provider" == "claude" ]]; then
    for a in "${CLAUDE_ALIASES[@]}"; do [[ "$a" == "$model" ]] && return 0; done
    echo "Error: claude alias must be one of: ${CLAUDE_ALIASES[*]} (got '$model')" >&2
    exit 2
  fi
  # The cache can lag behind new releases, so an unlisted slug only warns.
  local known
  known="$(codex_models | cut -f1)"
  if [[ -n "$known" ]] && ! grep -qxF "$model" <<<"$known"; then
    echo "Warning: '$model' is not in $CODEX_CACHE — check the slug" >&2
  fi
}

validate() {
  local stage="$1" value="$2" member seen=","
  local -a members
  is_stage "$stage" || { echo "Error: unknown stage '$stage' (stages: ${STAGES[*]})" >&2; exit 2; }
  [[ "$value" =~ ^[^,]+(,[^,]+)*$ ]] \
    || { echo "Error: '$value' is not a comma-separated list of models" >&2; exit 2; }
  IFS=',' read -r -a members <<<"$value"
  if (( ${#members[@]} > 1 )) && ! is_panel_stage "$stage"; then
    echo "Error: stage '$stage' takes exactly one model; only ${PANEL_STAGES[*]} accept a panel" >&2
    exit 2
  fi
  for member in "${members[@]}"; do
    validate_member "$member"
    [[ "$seen" != *",$member,"* ]] \
      || { echo "Error: '$member' is listed twice for stage '$stage'" >&2; exit 2; }
    seen+="$member,"
  done
}

cmd_show() {
  local stage
  printf '%-7s %-40s %s\n' STAGE MODELS SOURCE
  for stage in "${STAGES[@]}"; do
    resolve "$stage"
    printf '%-7s %-40s %s\n' "$stage" "$VALUE" "$SOURCE"
  done
}

cmd_get() {
  local stage="${1:-}"
  [[ -n "$stage" ]] || usage
  is_stage "$stage" || { echo "Error: unknown stage '$stage' (stages: ${STAGES[*]})" >&2; exit 2; }
  resolve "$stage"
  local member
  local -a members
  IFS=',' read -r -a members <<<"$VALUE"
  for member in "${members[@]}"; do
    echo "${member%%:*} ${member#*:}"
  done
}

cmd_set() {
  local target="$GLOBAL_CONF" pair stage value
  local -A updates=()
  if [[ "${1:-}" == "--project" ]]; then target="$PROJECT_CONF"; shift; fi
  [[ $# -gt 0 ]] || usage
  for pair in "$@"; do
    [[ "$pair" == *=* ]] || { echo "Error: expected stage=provider:model[,...], got '$pair'" >&2; exit 2; }
    stage="${pair%%=*}"; value="${pair#*=}"
    validate "$stage" "$value"
    updates[$stage]="$value"
  done

  # Keep stages already in the target file; leave the rest to fall through.
  local tmp
  tmp="$(mktemp)"
  {
    echo "# /collab stage → model map. Edit with: /collab-init"
    echo "# Values: codex:<slug> | claude:<opus|sonnet|haiku|fable>"
    echo "# plan and review accept a comma-separated panel; the first member is the lead."
    for stage in "${STAGES[@]}"; do
      value="${updates[$stage]:-$(lookup "$target" "$stage")}"
      [[ -n "$value" ]] && echo "$stage=$value"
    done
  } > "$tmp"
  mkdir -p "$(dirname "$target")"
  mv "$tmp" "$target"
  echo "Wrote $target"
  cmd_show
}

# Numbered so /collab-init can take "plan 2,9"-style answers.
cmd_models() {
  local slug name desc a n=0
  printf '%-3s %-22s %-18s %s\n' '#' VALUE NAME NOTES
  while IFS=$'\t' read -r slug name desc; do
    [[ -n "$slug" ]] || continue
    n=$((n + 1))
    printf '%-3s %-22s %-18s %s\n' "$n" "codex:$slug" "$name" "$desc"
  done < <(codex_models)
  for a in "${CLAUDE_ALIASES[@]}"; do
    n=$((n + 1))
    printf '%-3s %-22s %-18s %s\n' "$n" "claude:$a" "${CLAUDE_NAMES[$a]}" "Claude subagent"
  done
}

case "${1:-}" in
  show)   cmd_show ;;
  get)    shift; cmd_get "$@" ;;
  set)    shift; cmd_set "$@" ;;
  models) cmd_models ;;
  *)      usage ;;
esac
