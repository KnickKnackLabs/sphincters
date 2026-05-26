# drones

**Bounded one-shot agent workers with logs, transcripts, and result JSON.**

`drones` is a small extraction target for Ikma's `drone-lab` prototype. The first goal is not a full swarm manager; it is one reliable drone run that leaves behind enough evidence for a parent agent or human to inspect what happened.

## Quick start

```bash
mise trust
mise install
mise run run --dry-run --model fake/model --prompt "Say hello" --json
mise run test
```

## Shape

A drone run creates:

- a prompt file;
- a system prompt file for the stateless/plain profile;
- `sessions new` / `sessions wake` / `sessions read` logs;
- a transcript file;
- a result JSON file with paths and return codes.

The current skeleton supports `--dry-run` for tests and local development without launching a model.

## Provenance

This starts from `~/agents/ikma/home/.mise/tasks/drone-lab`, especially the one-shot runner and profile idea. The standalone version should keep the useful parts and drop home-specific assumptions as the interface stabilizes.
