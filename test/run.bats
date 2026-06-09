#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

make_mock_sessions() {
  export SPHINCTERS_SESSIONS_LOG="$BATS_TEST_TMPDIR/sessions.log"
  export SPHINCTERS_SESSIONS_ENV_LOG="$BATS_TEST_TMPDIR/sessions.env.log"
  export SPHINCTERS_SESSIONS_BIN="$BATS_TEST_TMPDIR/sessions"
  cat > "$SPHINCTERS_SESSIONS_BIN" <<'SESSIONS'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SPHINCTERS_SESSIONS_LOG:?}"
if [ "${1:-}" = "wake" ]; then
  {
    printf 'DESK_ROOT=%s\n' "${DESK_ROOT:-}"
    printf 'DESKS_ROOT=%s\n' "${DESKS_ROOT:-}"
  } >> "${SPHINCTERS_SESSIONS_ENV_LOG:?}"
fi
case "${1:-}" in
  new|wake)
    exit 0
    ;;
  read)
    printf 'mock transcript for %s\n' "${2:-}"
    ;;
  *)
    echo "unexpected sessions command: ${1:-}" >&2
    exit 64
    ;;
esac
SESSIONS
  chmod +x "$SPHINCTERS_SESSIONS_BIN"
}

make_mock_desks() {
  export SPHINCTERS_MOCK_DESKS_ROOT="$BATS_TEST_TMPDIR/desks"
  export SPHINCTERS_DESKS_LOG="$BATS_TEST_TMPDIR/desks.log"
  export SPHINCTERS_DESKS_BIN="$BATS_TEST_TMPDIR/desks-bin"
  cat > "$SPHINCTERS_DESKS_BIN" <<'DESKS'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SPHINCTERS_DESKS_LOG:?}"
root_base="${SPHINCTERS_MOCK_DESKS_ROOT:?}"
mkdir -p "$root_base"
case "${1:-}" in
  new)
    if [ "${2:-}" = "--id" ]; then
      id="${3:-}"
    else
      id="auto-desk"
    fi
    root="$root_base/$id"
    if [ -e "$root" ]; then
      echo "desk already exists: $id" >&2
      exit 1
    fi
    mkdir -p "$root/.desk"
    jq -n --arg id "$id" --arg root "$root" '{schema: 1, id: $id, root: $root}' > "$root/.desk/registry.json"
    printf '%s\n' "$root"
    ;;
  path)
    id="${2:-}"
    root="$root_base/$id"
    [ -f "$root/.desk/registry.json" ] || { echo "desk not found: $id" >&2; exit 1; }
    printf '%s\n' "$root"
    ;;
  *)
    echo "unexpected desks command: ${1:-}" >&2
    exit 64
    ;;
esac
DESKS
  chmod +x "$SPHINCTERS_DESKS_BIN"
}

@test "run --dry-run writes result JSON" {
  out_dir="$BATS_TEST_TMPDIR/run"
  run sphincters run --dry-run --model fake/model --prompt "hello" --out-dir "$out_dir" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.type == "sphincters-run" and .dry_run == true and .profile.kind == "plain" and .rc.wake == 0' >/dev/null
  result=$(echo "$output" | jq -r '.files.result')
  spec=$(echo "$output" | jq -r '.profile_spec_file')
  [ -f "$result" ]
  [ -f "$spec" ]
}

@test "run resolves relative paths against SPHINCTERS_CALLER_PWD" {
  caller="$BATS_TEST_TMPDIR/caller"
  mkdir -p "$caller"
  printf 'prompt from caller\n' > "$caller/prompt.md"

  export SPHINCTERS_CALLER_PWD="$caller"
  run sphincters run \
    --dry-run \
    --model fake/model \
    --prompt-file prompt.md \
    --out-dir out \
    --result-file results/result.json \
    --json
  unset SPHINCTERS_CALLER_PWD

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    --arg caller "$caller" \
    '.caller_pwd == $caller and .out_dir == ($caller + "/out") and .files.result == ($caller + "/results/result.json")' \
    >/dev/null
  prompt_copy=$(echo "$output" | jq -r '.files.prompt')
  [ "$(cat "$prompt_copy")" = "prompt from caller" ]
  [ -f "$caller/results/result.json" ]
}

@test "run can resolve model from SPHINCTERS_MODEL" {
  export SPHINCTERS_MODEL=fake/from-env
  run sphincters run --dry-run --prompt "hello" --json
  unset SPHINCTERS_MODEL

  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.model == "fake/from-env"' >/dev/null
}

@test "run --background dry-run returns attach handles and skips transcript read" {
  out_dir="$BATS_TEST_TMPDIR/background-run"
  run sphincters run \
    --dry-run \
    --background \
    --model fake/model \
    --prompt "hello" \
    --out-dir "$out_dir" \
    --name sibling-watch \
    --json

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    '.background == true
     and .read.skipped == true
     and .handles.attach == "shell attach sibling-watch"
     and .handles.status == "shell status sibling-watch"
     and .handles.wait == "shell wait sibling-watch"
     and .handles.read == "sessions read sibling-watch"
     and .rc.read == 0' \
    >/dev/null

  read_log=$(echo "$output" | jq -r '.files.logs.read')
  [[ "$(cat "$read_log")" == *"background run"* ]]
}

@test "run invokes headless sessions wake by default" {
  make_mock_sessions
  out_dir="$BATS_TEST_TMPDIR/headless-run"

  run sphincters run \
    --model fake/model \
    --prompt "hello" \
    --out-dir "$out_dir" \
    --name headless-run \
    --json

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    '.mode == "headless"
     and .background == false
     and .read.skipped == false
     and .rc.new == 0
     and .rc.wake == 0
     and .rc.read == 0' \
    >/dev/null

  wake_line=$(sed -n '2p' "$SPHINCTERS_SESSIONS_LOG")
  [[ "$wake_line" == wake\ headless-run* ]]
  [[ "$wake_line" == *"--headless"* ]]
  [[ "$wake_line" != *"--background"* ]]

  transcript=$(echo "$output" | jq -r '.files.transcript')
  [ "$(cat "$transcript")" = "mock transcript for headless-run" ]
}

@test "run --interactive --background starts attachable interactive wake" {
  make_mock_sessions
  out_dir="$BATS_TEST_TMPDIR/interactive-background-run"

  run sphincters run \
    --interactive \
    --background \
    --model fake/model \
    --prompt "hello" \
    --out-dir "$out_dir" \
    --name interactive-desk \
    --json

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    '.mode == "interactive"
     and .background == true
     and .read.skipped == true
     and .handles.attach == "shell attach interactive-desk"
     and .rc.new == 0
     and .rc.wake == 0
     and .rc.read == 0' \
    >/dev/null

  wake_line=$(sed -n '2p' "$SPHINCTERS_SESSIONS_LOG")
  [[ "$wake_line" == wake\ interactive-desk* ]]
  [[ "$wake_line" != *"--headless"* ]]
  [[ "$wake_line" == *"--background"* ]]
  [[ "$wake_line" == *"wait for the operator before side effects"* ]]
}

@test "run --interactive foreground requires a TTY" {
  run sphincters run --interactive --model fake/model --prompt "hello" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"--interactive without --background requires a TTY"* ]]
}

@test "sibling profile defaults to caller cwd and preserves inherited identity" {
  out_dir="$BATS_TEST_TMPDIR/sibling-run"
  caller="$BATS_TEST_TMPDIR/caller-workspace"
  agent_home="$BATS_TEST_TMPDIR/agent-home"
  mkdir -p "$caller" "$agent_home"

  export GIT_AUTHOR_NAME="baby-joel"
  export AGENT_HOME="$agent_home"
  export SPHINCTERS_CALLER_PWD="$caller"
  run sphincters run \
    --dry-run \
    --profile sibling \
    --model fake/model \
    --prompt "watch the PR" \
    --out-dir "$out_dir" \
    --json
  unset SPHINCTERS_CALLER_PWD
  unset AGENT_HOME
  unset GIT_AUTHOR_NAME

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    --arg caller "$caller" \
    '.profile.name == "sibling"
     and .profile.kind == "agent"
     and .profile.subject == "sibling"
     and .cwd == $caller
     and .profile_spec.identity.mode == "inherit"
     and .profile_spec.identity.agent == "baby-joel"
     and (.profile_spec.unset_env | length) == 0
     and .profile_spec.meta["agent.name"] == "baby-joel"' \
    >/dev/null

  system_prompt=$(echo "$output" | jq -r '.files.system_prompt')
  [[ "$(cat "$system_prompt")" == *"baby-joel in a same-agent sibling session"* ]]
  [[ "$(cat "$system_prompt")" == *"subordinate worker"* ]]
}

@test "sibling profile honors explicit cwd over caller cwd" {
  out_dir="$BATS_TEST_TMPDIR/sibling-explicit-run"
  caller="$BATS_TEST_TMPDIR/caller-workspace"
  explicit="$BATS_TEST_TMPDIR/explicit-workspace"
  mkdir -p "$caller" "$explicit"

  export SPHINCTERS_CALLER_PWD="$caller"
  run sphincters run \
    --dry-run \
    --profile sibling \
    --model fake/model \
    --prompt "watch the PR" \
    --cwd "$explicit" \
    --out-dir "$out_dir" \
    --json
  unset SPHINCTERS_CALLER_PWD

  [ "$status" -eq 0 ]
  echo "$output" | jq -e --arg explicit "$explicit" '.cwd == $explicit' >/dev/null
}

@test "run composes repeated profiles in CLI order" {
  out_dir="$BATS_TEST_TMPDIR/composed-run"
  caller="$BATS_TEST_TMPDIR/caller-workspace"
  mkdir -p "$caller"

  export GIT_AUTHOR_NAME="baby-joel"
  export SPHINCTERS_CALLER_PWD="$caller"
  run sphincters run \
    --dry-run \
    --profile desk \
    --profile sibling \
    --model fake/model \
    --prompt "watch the PR" \
    --out-dir "$out_dir" \
    --json
  unset SPHINCTERS_CALLER_PWD
  unset GIT_AUTHOR_NAME

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    --arg caller "$caller" \
    --arg out_dir "$out_dir" \
    '.profile.name == "desk+sibling"
     and .profile.kind == "composed"
     and .profile.subject == "sibling"
     and .profiles[0].name == "desk"
     and .profiles[1].name == "sibling"
     and .profile_stack == ["desk", "sibling"]
     and .cwd == $caller
     and .outputs.desk_root == ($out_dir + "/dry-run-desk")
     and .outputs.desks_root == ($out_dir + "/dry-run-desk/.desks")
     and .profile_outputs.desk.desk_id == "dry-run-desk"
     and .profile_outputs.sibling == {}
     and .cleanup[0].profile == "desk"
     and .profile_spec.env.DESK_ROOT == ($out_dir + "/dry-run-desk")
     and .profile_spec.env.DESKS_ROOT == ($out_dir + "/dry-run-desk/.desks")' \
    >/dev/null
}

@test "desk profile injects desk env into launched wake" {
  make_mock_sessions
  make_mock_desks
  out_dir="$BATS_TEST_TMPDIR/desk-launch"
  caller="$BATS_TEST_TMPDIR/caller-workspace"
  mkdir -p "$caller"

  export GIT_AUTHOR_NAME="baby-joel"
  export SPHINCTERS_CALLER_PWD="$caller"
  export SPHINCTERS_DESK_ID="desk-a"
  run sphincters run \
    --profile desk \
    --profile sibling \
    --interactive \
    --background \
    --model fake/model \
    --prompt "hello" \
    --out-dir "$out_dir" \
    --name desk-sibling \
    --json
  unset SPHINCTERS_DESK_ID
  unset SPHINCTERS_CALLER_PWD
  unset GIT_AUTHOR_NAME

  [ "$status" -eq 0 ]
  desk_root="$SPHINCTERS_MOCK_DESKS_ROOT/desk-a"
  echo "$output" | jq -e \
    --arg caller "$caller" \
    --arg desk_root "$desk_root" \
    '.profile_stack == ["desk", "sibling"]
     and .cwd == $caller
     and .desk_root == $desk_root
     and .desks_root == ($desk_root + "/.desks")
     and .desk_id == "desk-a"
     and .profile_outputs.desk.created == true' \
    >/dev/null

  [ "$(cat "$SPHINCTERS_DESKS_LOG")" = "new --id desk-a" ]
  grep -Fx "DESK_ROOT=$desk_root" "$SPHINCTERS_SESSIONS_ENV_LOG"
  grep -Fx "DESKS_ROOT=$desk_root/.desks" "$SPHINCTERS_SESSIONS_ENV_LOG"
}

@test "desk profile dry-run rejects unsafe desk ids" {
  export SPHINCTERS_DESK_ID="../bad"
  run sphincters run --dry-run --profile desk --model fake/model --prompt "hello" --json
  unset SPHINCTERS_DESK_ID

  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid desk id: ../bad"* ]]
}

@test "profile composition rejects env conflicts" {
  profile_dir="$BATS_TEST_TMPDIR/conflict-profiles"
  mkdir -p "$profile_dir"
  cat > "$profile_dir/a" <<'PROFILE'
#!/usr/bin/env bash
jq -n '{version: 1, profile: {name: "a", kind: "test", subject: "a"}, env: {CONFLICT: "one"}}'
PROFILE
  cat > "$profile_dir/b" <<'PROFILE'
#!/usr/bin/env bash
jq -n '{version: 1, profile: {name: "b", kind: "test", subject: "b"}, env: {CONFLICT: "two"}}'
PROFILE
  chmod +x "$profile_dir/a" "$profile_dir/b"

  export SPHINCTERS_PROFILE_PATH="$profile_dir"
  run sphincters run --dry-run --profile a --profile b --model fake/model --prompt "hello" --json
  unset SPHINCTERS_PROFILE_PATH

  [ "$status" -eq 2 ]
  [[ "$output" == *"profile conflict for env.CONFLICT"* ]]
}

@test "run can use an external profile from SPHINCTERS_PROFILE_PATH" {
  profile_dir="$BATS_TEST_TMPDIR/profiles"
  mkdir -p "$profile_dir"
  cat > "$profile_dir/custom" <<'PROFILE'
#!/usr/bin/env bash
set -euo pipefail
cwd="${SPHINCTERS_CWD:-$SPHINCTERS_OUT_DIR/custom-cwd}"
system_prompt_file="$SPHINCTERS_OUT_DIR/custom-system.md"
mkdir -p "$cwd"
printf 'custom system prompt\n' > "$system_prompt_file"
jq -n \
  --arg cwd "$cwd" \
  --arg system_prompt_file "$system_prompt_file" \
  '{version: 1, profile: {name: "custom", kind: "test", subject: "fixture"}, cwd: $cwd, system_prompt_file: $system_prompt_file, identity: {mode: "skip"}, unset_env: ["GH_TOKEN"], meta: {"fixture.profile": "custom"}}'
PROFILE
  chmod +x "$profile_dir/custom"

  export SPHINCTERS_PROFILE_PATH="$profile_dir"
  run sphincters run --dry-run --profile custom --model fake/model --prompt "hello" --json
  unset SPHINCTERS_PROFILE_PATH

  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.profile.name == "custom" and .profile.kind == "test" and .profile_spec.meta["fixture.profile"] == "custom"' >/dev/null
  system_prompt=$(echo "$output" | jq -r '.files.system_prompt')
  [ "$(cat "$system_prompt")" = "custom system prompt" ]
}

@test "run rejects unknown profiles" {
  run sphincters run --dry-run --profile missing --model fake/model --prompt "hello" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"profile executable not found: missing"* ]]
}

@test "run rejects invalid profile specs" {
  profile_dir="$BATS_TEST_TMPDIR/bad-profiles"
  mkdir -p "$profile_dir"
  cat > "$profile_dir/bad" <<'PROFILE'
#!/usr/bin/env bash
printf '{}\n'
PROFILE
  chmod +x "$profile_dir/bad"

  export SPHINCTERS_PROFILE_PATH="$profile_dir"
  run sphincters run --dry-run --profile bad --model fake/model --prompt "hello" --json
  unset SPHINCTERS_PROFILE_PATH

  [ "$status" -eq 2 ]
  [[ "$output" == *"profile emitted invalid launch spec"* ]]
}

@test "run rejects unsafe session names" {
  run sphincters run --dry-run --model fake/model --prompt "hello" --name "../bad" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid session name"* ]]
}

@test "run requires a prompt" {
  run sphincters run --dry-run --model fake/model --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"must provide --prompt or --prompt-file"* ]]
}
