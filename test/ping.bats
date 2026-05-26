#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

@test "ping --dry-run writes ping summary JSON" {
  out_dir="$BATS_TEST_TMPDIR/ping"
  run sphincters ping --dry-run --model fake/model --out-dir "$out_dir" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.type == "sphincters-ping" and .dry_run == true and .ack_ok == null and .rc.run == 0 and .run.rc.wake == 0' >/dev/null
  result=$(echo "$output" | jq -r '.result_file')
  run_result=$(echo "$output" | jq -r '.run_result_file')
  [ -f "$result" ]
  [ -f "$run_result" ]
}

@test "ping uses deterministic ACK prompt when no prompt is supplied" {
  out_dir="$BATS_TEST_TMPDIR/ping-ack"
  run sphincters ping --dry-run --model fake/model --out-dir "$out_dir" --name fixture-ping --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.expected_ack == "DRONE_ACK fixture-ping"' >/dev/null
  prompt_file=$(echo "$output" | jq -r '.run.files.prompt')
  grep -q 'DRONE_ACK fixture-ping' "$prompt_file"
}

@test "ping does not expect ACK when caller supplies a prompt" {
  run sphincters ping --dry-run --model fake/model --prompt "custom prompt" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.expected_ack == null and .ack_ok == null' >/dev/null
}
