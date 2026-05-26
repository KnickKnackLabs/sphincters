drones() {
  local caller
  caller="${DRONES_CALLER_PWD:-$REPO_DIR}"
  cd "$REPO_DIR" && env DRONES_CALLER_PWD="$caller" mise run -q "$@"
}
export -f drones
