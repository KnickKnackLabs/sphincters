#!/usr/bin/env bash
# Shared helpers for drones tasks. Source from mise tasks only.

if [ -z "${MISE_CONFIG_ROOT:-}" ]; then
  echo "error: lib/drones.sh must be sourced from a mise task" >&2
  exit 2
fi

DRONES_REPO_DIR="$MISE_CONFIG_ROOT"

drones_now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

drones_safe_name() {
  tr -c 'A-Za-z0-9._-' '_' | sed 's/^_*//; s/_*$//'
}

drones_resolve_model() {
  local model="$1"
  model="${model:-${DRONES_MODEL:-${SESSIONS_DEFAULT_MODEL:-}}}"
  if [ -z "$model" ]; then
    cat >&2 <<'ERR'
error: model is required

Pass --model <provider/model> or set DRONES_MODEL / SESSIONS_DEFAULT_MODEL.
ERR
    exit 2
  fi
  printf '%s\n' "$model"
}

drones_plain_system_prompt() {
  cat <<'PROMPT'
You are a stateless drone: a short-lived worker process for one scoped task.

You do not have durable memory or prior conversation context. Complete the
requested task directly, follow the output contract exactly, and stop. Do not
perform side effects unless the prompt explicitly allows them.
PROMPT
}
