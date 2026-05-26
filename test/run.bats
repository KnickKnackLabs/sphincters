#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

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
