#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

@test "bench --dry-run runs requested pings" {
  out_dir="$BATS_TEST_TMPDIR/bench"
  run sphincters bench --dry-run --model fake/model --count 3 --parallel 2 --out-dir "$out_dir" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.type == "sphincters-bench" and .dry_run == true and .count_requested == 3 and .count_observed == 3 and .success == 3 and (.pings | length) == 3' >/dev/null
  [ -f "$out_dir/summary.json" ]
}

@test "bench validates count" {
  run sphincters bench --dry-run --model fake/model --count 0 --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"--count must be a positive integer"* ]]
}

@test "bench validates parallel" {
  run sphincters bench --dry-run --model fake/model --parallel nope --json
  [ "$status" -eq 2 ]
  [[ "$output" == *"--parallel must be a positive integer"* ]]
}
