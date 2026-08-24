#!/usr/bin/env bash
# Shared helpers for drones tasks and tests.

DRONES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRONES_REPO_DIR="$(cd "$DRONES_LIB_DIR/.." && pwd)"

# Paths passed to an installed shiv package are caller-relative. Direct mise
# runs fall back to the current shell's PWD.
drones_caller_pwd() {
  printf '%s\n' "${SPHINCTERS_CALLER_PWD:-${CALLER_PWD:-$PWD}}"
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

drones_now_ms() {
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%d\n", time() * 1000'
  else
    printf '%s000\n' "$(date +%s)"
  fi
}

drones_now_iso() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

drones_safe_name() {
  tr -c 'A-Za-z0-9._-' '_' | sed 's/^_*//; s/_*$//'
}

drones_join_by() {
  local sep="$1"
  shift

  local first=true item
  for item in "$@"; do
    if [ "$first" = "true" ]; then
      first=false
    else
      printf '%s' "$sep"
    fi
    printf '%s' "$item"
  done
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

drones_check_json_schema() {
  local schema_file="$1" instance_file="$2" output

  if ! output=$(check-jsonschema --schemafile "$schema_file" "$instance_file" 2>&1); then
    printf '%s\n' "$output" >&2
    return 1
  fi
}

drones_validate_profile_spec_file() {
  local file="$1"

  drones_check_json_schema \
    "$DRONES_REPO_DIR/schemas/profile-spec.schema.json" \
    "$file"
}

drones_validate_launch_spec_file() {
  local file="$1"

  drones_check_json_schema \
    "$DRONES_REPO_DIR/schemas/launch-spec.schema.json" \
    "$file"
}

drones_write_initial_profile_context() {
  local output_file="$1" cwd="$2"

  jq -n --arg cwd "$cwd" '{
    version: 1,
    profile: {name: "", kind: "composed", subject: ""},
    profiles: [],
    profile_stack: [],
    cwd: $cwd,
    system_prompt_file: "",
    identity: null,
    unset_env: [],
    env: {},
    meta: {},
    outputs: {},
    profile_outputs: {},
    cleanup: []
  }' > "$output_file"
}

drones_compose_profile_context() {
  local context_file="$1" spec_file="$2" output_file="$3"

  jq -n \
    --slurpfile ctx "$context_file" \
    --slurpfile next "$spec_file" \
    '
      def fail($message): error($message);

      def choose_string($ctx; $next; $field):
        ($ctx[$field] // "") as $old |
        ($next[$field] // "") as $new |
        if $new == "" then $old
        elif $old == "" then $new
        elif $old == $new then $old
        else fail("profile conflict for \($field): \($old) vs \($new)")
        end;

      def choose_identity($ctx; $next):
        ($ctx.identity // null) as $old |
        ($next.identity // null) as $new |
        if $new == null then $old
        elif $old == null then $new
        elif $old == $new then $old
        else fail("profile conflict for identity")
        end;

      def merge_no_conflict($old; $new; $label):
        reduce (((($old // {}) | keys_unsorted) + (($new // {}) | keys_unsorted)) | unique[]) as $key
          ({};
            if (($old // {}) | has($key)) and (($new // {}) | has($key)) then
              if $old[$key] == $new[$key] then
                .[$key] = $old[$key]
              else
                fail("profile conflict for \($label).\($key)")
              end
            elif (($new // {}) | has($key)) then
              .[$key] = $new[$key]
            else
              .[$key] = $old[$key]
            end
          );

      ($ctx[0] // {}) as $ctx |
      $next[0] as $next |
      ($next.profile.name) as $profile_name |
      if (($ctx.profile_outputs // {}) | has($profile_name)) then
        fail("duplicate profile in stack: \($profile_name)")
      else
        (($ctx.profiles // []) + [$next.profile]) as $profiles |
        (($ctx.profile_stack // []) + [$profile_name]) as $profile_stack |
        (merge_no_conflict($ctx.env; $next.env; "env")) as $env |
        (((($ctx.unset_env // []) + ($next.unset_env // [])) | unique)) as $unset_env |
        ([ $unset_env[] as $name | if ($env | has($name)) then $name else empty end ]) as $env_conflicts |
        if ($env_conflicts | length) > 0 then
          fail("profile conflict: env key is both set and unset: \($env_conflicts[0])")
        else
          {
            version: 1,
            profile: {name: "", kind: "composed", subject: ""},
            profiles: $profiles,
            profile_stack: $profile_stack,
            cwd: choose_string($ctx; $next; "cwd"),
            system_prompt_file: choose_string($ctx; $next; "system_prompt_file"),
            identity: choose_identity($ctx; $next),
            unset_env: $unset_env,
            env: $env,
            meta: merge_no_conflict($ctx.meta; $next.meta; "meta"),
            outputs: merge_no_conflict($ctx.outputs; $next.outputs; "outputs"),
            profile_outputs: (($ctx.profile_outputs // {}) + {($profile_name): ($next.outputs // {})}),
            cleanup: (($ctx.cleanup // []) + (if ($next.cleanup? == null) then [] else [{profile: $profile_name, cleanup: $next.cleanup}] end))
          }
        end
      end
    ' > "$output_file"
}

drones_finalize_profile_context() {
  local context_file="$1" output_file="$2" fallback_cwd="$3" out_dir="$4" caller_pwd="$5" profile_files_file="$6"

  jq -n \
    --slurpfile ctx "$context_file" \
    --slurpfile profile_files "$profile_files_file" \
    --arg fallback_cwd "$fallback_cwd" \
    --arg out_dir "$out_dir" \
    --arg caller_pwd "$caller_pwd" \
    '
      def fail($message): error($message);

      def merge_no_conflict($old; $new; $label):
        reduce (((($old // {}) | keys_unsorted) + (($new // {}) | keys_unsorted)) | unique[]) as $key
          ({};
            if (($old // {}) | has($key)) and (($new // {}) | has($key)) then
              if $old[$key] == $new[$key] then
                .[$key] = $old[$key]
              else
                fail("profile conflict for \($label).\($key)")
              end
            elif (($new // {}) | has($key)) then
              .[$key] = $new[$key]
            else
              .[$key] = $old[$key]
            end
          );

      ($ctx[0] // {}) as $ctx |
      ($ctx.profiles // []) as $profiles |
      ($ctx.profile_stack // []) as $profile_stack |
      if ($profiles | length) == 0 then
        fail("no profiles to compose")
      else
        (if ($ctx.cwd // "") == "" then $fallback_cwd else $ctx.cwd end) as $cwd |
        (if ($profiles | length) == 1 then
          $profiles[0]
        else
          {
            name: ($profile_stack | join("+")),
            kind: "composed",
            subject: ($profiles[-1].subject // "composed")
          }
        end) as $profile |
        {
          "drone.tool": "sphincters",
          "drone.profile": $profile.name,
          "drone.profiles": ($profile_stack | join(",")),
          "drone.kind": $profile.kind,
          "drone.subject": $profile.subject,
          "drone.out_dir": $out_dir,
          "drone.caller_pwd": $caller_pwd
        } as $runner_meta |
        {
          version: 1,
          profile: $profile,
          profiles: $profiles,
          profile_stack: $profile_stack,
          cwd: $cwd,
          system_prompt_file: ($ctx.system_prompt_file // ""),
          identity: ($ctx.identity // null),
          unset_env: ($ctx.unset_env // []),
          env: ($ctx.env // {}),
          meta: merge_no_conflict($ctx.meta; $runner_meta; "meta"),
          outputs: ($ctx.outputs // {}),
          profile_outputs: ($ctx.profile_outputs // {}),
          cleanup: ($ctx.cleanup // []),
          profile_spec_files: ($profile_files[0] // [])
        }
      end
    ' > "$output_file"
}

drones_require_positive_int() {
  local name="$1" value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ]; then
    echo "error: --$name must be a positive integer (got: $value)" >&2
    exit 2
  fi
}

drones_profile_roots() {
  local roots="${SPHINCTERS_PROFILE_PATH:-${DRONES_PROFILE_PATH:-$DRONES_REPO_DIR/profiles}}"
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
  model="${model:-${SPHINCTERS_MODEL:-${DRONES_MODEL:-${SESSIONS_DEFAULT_MODEL:-}}}}"
  if [ -z "$model" ]; then
    cat >&2 <<'ERR'
error: model is required

Pass --model <provider/model> or set SPHINCTERS_MODEL / SESSIONS_DEFAULT_MODEL.
ERR
    exit 2
  fi
  printf '%s\n' "$model"
}

drones_default_ping_prompt() {
  local session_name="$1"
  cat <<PROMPT
Reply exactly this single line and then stop:

DRONE_ACK $session_name

Do not use tools.
PROMPT
}

drones_plain_system_prompt() {
  cat <<'PROMPT'
You are a stateless drone: a short-lived worker process for one scoped task.

You do not have durable memory or prior conversation context. Complete the
requested task directly, follow the output contract exactly, and stop. Do not
perform side effects unless the prompt explicitly allows them.
PROMPT
}
