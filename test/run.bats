#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

@test "run --dry-run writes result JSON" {
  out_dir="$BATS_TEST_TMPDIR/run"
  run drones run --dry-run --model fake/model --prompt "hello" --out-dir "$out_dir" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.type == "drones-run" and .dry_run == true and .rc.wake == 0' >/dev/null
  result=$(echo "$output" | jq -r '.files.result')
  [ -f "$result" ]
}

@test "run resolves relative paths against DRONES_CALLER_PWD" {
  caller="$BATS_TEST_TMPDIR/caller"
  mkdir -p "$caller"
  printf 'prompt from caller\n' > "$caller/prompt.md"

  export DRONES_CALLER_PWD="$caller"
  run drones run \
    --dry-run \
    --model fake/model \
    --prompt-file prompt.md \
    --out-dir out \
    --result-file results/result.json \
    --json
  unset DRONES_CALLER_PWD

  [ "$status" -eq 0 ]
  echo "$output" | jq -e \
    --arg caller "$caller" \
    '.caller_pwd == $caller and .out_dir == ($caller + "/out") and .files.result == ($caller + "/results/result.json")' \
    >/dev/null
  prompt_copy=$(echo "$output" | jq -r '.files.prompt')
  [ "$(cat "$prompt_copy")" = "prompt from caller" ]
  [ -f "$caller/results/result.json" ]
}

@test "run can resolve model from DRONES_MODEL" {
  export DRONES_MODEL=fake/from-env
  run drones run --dry-run --prompt "hello" --json
  unset DRONES_MODEL

  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.model == "fake/from-env"' >/dev/null
}

@test "run rejects unsafe session names" {
  run drones run --dry-run --model fake/model --prompt "hello" --name "../bad" --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid session name"* ]]
}

@test "run requires a prompt" {
  run drones run --dry-run --model fake/model --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"must provide --prompt or --prompt-file"* ]]
}
