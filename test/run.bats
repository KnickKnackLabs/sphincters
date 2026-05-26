#!/usr/bin/env bats

load test_helper

@test "run --dry-run writes result JSON" {
  out_dir="$BATS_TEST_TMPDIR/run"
  run drones run --dry-run --model fake/model --prompt "hello" --out-dir "$out_dir" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.type == "drones-run" and .dry_run == true and .rc.wake == 0' >/dev/null
  result=$(echo "$output" | jq -r '.files.result')
  [ -f "$result" ]
}

@test "run requires a prompt" {
  run drones run --dry-run --model fake/model --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"must provide --prompt or --prompt-file"* ]]
}
