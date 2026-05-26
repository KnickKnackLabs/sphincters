sphincters() {
  local caller
  caller="${SPHINCTERS_CALLER_PWD:-$REPO_DIR}"
  cd "$REPO_DIR" && env SPHINCTERS_CALLER_PWD="$caller" mise run -q "$@"
}
export -f sphincters
