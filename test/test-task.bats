#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load test_helper

write_passing_test() {
  local path="$1" name="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' \
    '#!/usr/bin/env bats' \
    "@test \"$name\" {" \
    '  true' \
    '}' > "$path"
}

@test "options-only calls use the configured default test directory" {
  run sphincters test --jobs 1 --filter '^ping --dry-run writes ping summary JSON$'

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 ping --dry-run writes ping summary JSON'* ]]
}

@test "an explicit test target takes precedence over the configured default" {
  local target="$BATS_TEST_TMPDIR/explicit.bats"
  write_passing_test "$target" 'explicit target only'

  run sphincters test --jobs 1 "$target"

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 explicit target only'* ]]
}

@test "relative test targets resolve from the repository root" {
  run sphincters test --jobs 1 test/ping.bats --filter '^ping --dry-run writes ping summary JSON$'

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 ping --dry-run writes ping summary JSON'* ]]
}

@test "whitespace-bearing explicit test targets remain one argument" {
  local target="$BATS_TEST_TMPDIR/explicit target/passing test.bats"
  write_passing_test "$target" 'whitespace target'

  run sphincters test --jobs 2 "$target"

  [ "$status" -eq 0 ]
  [[ "$output" == *'1..1'* ]]
  [[ "$output" == *'ok 1 whitespace target'* ]]
}

@test "public Sphincters test path runs separate BATS files concurrently" {
  local probe_dir="$BATS_TEST_TMPDIR/across-file-probe"
  local barrier_dir="$BATS_TEST_TMPDIR/across-file-barrier"
  mkdir -p "$probe_dir" "$barrier_dir"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first worker observes second worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/one.bats"

  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"second worker observes first worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/two.bats"

  export PROBE_DIR="$barrier_dir"
  run sphincters test "$probe_dir"

  [ "$status" -eq 0 ]
}

@test "public Sphincters test path runs tests within one BATS file concurrently" {
  local probe_dir="$BATS_TEST_TMPDIR/within-file-probe"
  export PROBE_DIR="$BATS_TEST_TMPDIR/within-file-barrier"
  mkdir -p "$probe_dir" "$PROBE_DIR"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first test observes second test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
    printf '%s\n' "$test_keyword \"second test observes first test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/within-file.bats"

  run sphincters test "$probe_dir"

  [ "$status" -eq 0 ]
}
