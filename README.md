# drones

**Run one short-lived agent worker, then leave the evidence behind.**

`drones` is a small extraction from Ikma's `drone-lab` prototype. It is intentionally not a swarm manager yet. The stable unit is one bounded, stateless worker run with a prompt, logs, transcript, and machine-readable result JSON.

## Quick start

```bash
mise trust
mise install

# No model call; writes prompt/log/result files only.
mise run run --dry-run --model fake/model --prompt "Say hello" --json

mise run test
mise run lint
```

## Run contract

A run creates an output directory containing:

- the copied prompt file;
- the generated stateless system prompt;
- `sessions new`, `sessions wake`, and `sessions read` logs;
- a transcript file;
- a result JSON file with paths, timestamps, and return codes.

Relative `--prompt-file`, `--cwd`, `--out-dir`, and `--result-file` paths resolve against `DRONES_CALLER_PWD` when installed through `shiv`, or the current directory during direct `mise run` use.

```bash
mise run run \
  --model openai-codex/gpt-5.5 \
  --prompt-file task.md \
  --out-dir exports/first-drone \
  --json
```

Plain drones scrub agent identity and common side-effect credentials before waking. They should draft or report unless the prompt and environment deliberately permit side effects.

## Codebase health

This repo declares `shiv:codebase` and keeps convention checks local:

```bash
mise run lint
mise exec -- codebase pre-commit --check
```

The current lint set covers mise settings, BATS helper/task shape, `$MISE_CONFIG_ROOT` scope, `|| true`, and shellcheck.

## Provenance

This starts from `~/agents/ikma/home/.mise/tasks/drone-lab`, especially the one-shot runner and plain profile. The standalone version keeps the useful parts and drops home-specific assumptions as the interface stabilizes.
