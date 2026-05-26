#!/usr/bin/env bash
# Shared helpers for drones tasks and tests.

DRONES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRONES_REPO_DIR="$(cd "$DRONES_LIB_DIR/.." && pwd)"

# Paths passed to an installed shiv package are caller-relative. Direct mise
# runs fall back to the current shell's PWD.
drones_caller_pwd() {
  printf '%s\n' "${DRONES_CALLER_PWD:-$PWD}"
}

drones_resolve_path() {
  local path="$1"
  local caller
  caller=$(drones_caller_pwd)

  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s\n' "$caller/$path" ;;
  esac
}

drones_mkdir_parent() {
  local file="$1"
  local parent
  parent=$(dirname "$file")
  [ "$parent" = "." ] || mkdir -p "$parent"
}

drones_now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

drones_safe_name() {
  tr -c 'A-Za-z0-9._-' '_' | sed 's/^_*//; s/_*$//'
}

drones_validate_session_name() {
  local name="$1"
  if [ -z "$name" ] || [ "$name" = "." ] || [ "$name" = ".." ] || ! [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    cat >&2 <<ERR
error: invalid session name: $name

Names must contain only letters, numbers, dots, underscores, and hyphens.
ERR
    return 2
  fi
}

drones_validate_env_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

drones_profile_roots() {
  local roots="${DRONES_PROFILE_PATH:-$DRONES_REPO_DIR/profiles}"
  local rest root
  rest="$roots:"
  while [ -n "$rest" ]; do
    root="${rest%%:*}"
    rest="${rest#*:}"
    [ -n "$root" ] && printf '%s\n' "$root"
  done
}

drones_profile_executable() {
  local profile="$1"
  local root first rest exact fallback

  first="${profile%%/*}"
  if [ "$first" = "$profile" ]; then
    rest=""
  else
    rest="${profile#*/}"
  fi

  while IFS= read -r root; do
    exact="$root/$profile"
    if [ -x "$exact" ] && [ ! -d "$exact" ]; then
      DRONES_PROFILE_EXEC="$exact"
      DRONES_PROFILE_SUFFIX=""
      return 0
    fi

    if [ -n "$rest" ]; then
      fallback="$root/$first/_default"
      if [ -x "$fallback" ] && [ ! -d "$fallback" ]; then
        DRONES_PROFILE_EXEC="$fallback"
        DRONES_PROFILE_SUFFIX="$rest"
        return 0
      fi
    fi
  done < <(drones_profile_roots)

  echo "error: profile executable not found: $profile" >&2
  echo "searched roots:" >&2
  drones_profile_roots | sed 's/^/  /' >&2
  exit 2
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
