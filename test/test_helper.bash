drones() {
  cd "$REPO_DIR" && mise run -q "$@"
}
export -f drones
