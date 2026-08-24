<div align="center">

<p align="center"><img src="assets/hero.png" alt="Sphincters mascot" width="360" /></p>

# sphincters

**Launch worker sessions through profiles and keep their records inspectable.**

`sphincters` wraps session launch patterns in a small, profile-driven interface. It records prompts, profile specs, logs, transcripts, and result JSON so a parent process can inspect the run later.

![lang: bash](https://img.shields.io/badge/lang-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 29 passing](https://img.shields.io/badge/tests-29%20passing-brightgreen?style=flat)](test/)
![workers: 3 commands](https://img.shields.io/badge/workers-3%20commands-blue?style=flat)
![install: shiv](https://img.shields.io/badge/install-shiv-orange?style=flat)

</div>

<br />

## Quick start

```bash
# Install the latest released sphincter
shiv install sphincters

# Check the plumbing without launching a model
sphincters ping --dry-run --model fake/model --json

# Start a worker session
sphincters run \
  --profile plain \
  --model openai-codex/gpt-5.5 \
  --prompt-file task.md \
  --out-dir exports/first-run \
  --json

# Start a non-blocking same-agent sibling and return attach handles
sphincters run \
  --profile sibling \
  --background \
  --model openai-codex/gpt-5.5 \
  --prompt-file handoff.md \
  --json

# Start an interactive same-agent sibling desk for live attach
sphincters run \
  --profile sibling \
  --interactive \
  --background \
  --model openai-codex/gpt-5.5 \
  --prompt-file handoff.md \
  --json

# Compose workspace + identity decorators in deterministic CLI order
sphincters run \
  --profile desk \
  --profile sibling \
  --interactive \
  --background \
  --model openai-codex/gpt-5.5 \
  --prompt-file handoff.md \
  --json

# Run repeated smoke checks
sphincters bench --model openai-codex/gpt-5.5 --count 3 --parallel 1 --json
```

## What it is

`sphincters` is a small runner for worker sessions. The runner owns `sessions new`, `sessions wake`, `sessions read`, logging, and result JSON. Runs are headless by default; `--interactive` wakes a human-present session instead. With `--background`, the runner skips the blocking read step and returns attach/read handles instead. Profiles describe how the worker should be launched.

```
                 sphincters run
                       │
                       ▼
             ┌──────────────────┐
             │ profile stack    │  CLI order: desk → sibling
             └─────────┬────────┘
                       │ composed profile.json
                       ▼
  prompt.md ──▶ sessions new ──▶ sessions wake [--headless] ──▶ sessions read
                       │                    │                       │
                       │                    │                       └─ skipped with --background
                       └────────────────────┴───────────────────────┘
                                            ▼
      logs + transcript/result JSON + profile outputs + attach handles
```

The core abstraction is worker/profile/session. Profiles are applied in the order supplied on the CLI and contribute to one shared launch context. The runner launches exactly once from that composed context and records both the profile stack and each profile's outputs.

## Run modes

`sphincters run` has two separate axes: session mode and process mode. Runs are **headless** by default; `--interactive` makes the session human-present. Runs are **foreground** by default; `--background` launches through shell/zmx and returns handles.

| Command shape | What happens | Use when |
| --- | --- | --- |
| `sphincters run ...` | Headless foreground run; waits, then collects transcript. | One bounded worker answer now. |
| `sphincters run --background ...` | Headless background run; returns attach/status/wait/read handles and skips transcript collection. | A sibling scout or worker should run while the parent continues. |
| `sphincters run --interactive --background ...` | Interactive background session; returns an attachable desk handle. | Or or a lead agent may join the sibling and talk. |
| `sphincters run --interactive ...` | Interactive foreground session; requires a TTY and blocks until it exits. | A human intentionally starts sphincters from a terminal and wants to enter that session immediately. |

Foreground interactive mode fails loudly without a TTY. Agents should normally use `--interactive --background` for attachable sibling desks.

## Run records

Every run writes a directory that a human or parent process can inspect. If a worker failed, the logs are already separated by phase. If it succeeded, the transcript and result JSON point at each other.

```
exports/first-run/
├── sphincters-run-desk-sibling-...prompt.md
├── sphincters-run-desk-sibling-...profile.0.desk.json
├── sphincters-run-desk-sibling-...profile.1.sibling.json
├── sphincters-run-desk-sibling-...profile.json
├── sibling-system-prompt.md
├── sphincters-run-desk-sibling-...new.log
├── sphincters-run-desk-sibling-...wake.log
├── sphincters-run-desk-sibling-...read.log
├── sphincters-run-desk-sibling-...transcript.txt
└── sphincters-run-desk-sibling-...result.json
```

## Profiles are launch adapters

A profile is an executable under `profiles/` or `SPHINCTERS_PROFILE_PATH`. It prepares launch context and prints a JSON spec. `plain` creates a stateless system prompt and scrubs ambient identity. `desk` creates or selects a desk, injects `DESK_ROOT` and `DESKS_ROOT`, and records cleanup hints. `sibling` preserves inherited agent identity, defaults to the caller cwd, and frames the launched session as same-agent sibling/continuation work rather than a subordinate worker.

Composition is deterministic: `--profile desk --profile sibling` applies `desk` first and `sibling` second. Important fields such as cwd, identity, env keys, metadata, and outputs fail on conflicting writes instead of silently taking the last value. The desk profile uses the repo-pinned `desks` tool by default; set `SPHINCTERS_DESKS_BIN` to point at a stub or alternate binary.

<details>
<summary><b>Profile JSON contract</b></summary>

```json
{
  "version": 1,
  "profile": {"name": "desk", "kind": "workspace", "subject": "desk"},
  "unset_env": [],
  "env": {
    "DESK_ROOT": "/tmp/desks/demo",
    "DESKS_ROOT": "/tmp/desks/demo/.desks"
  },
  "meta": {"desk.id": "demo"},
  "outputs": {
    "desk_id": "demo",
    "desk_root": "/tmp/desks/demo",
    "desks_root": "/tmp/desks/demo/.desks"
  },
  "cleanup": {"strategy": "rm-rf", "path": "/tmp/desks/demo"}
}
```

</details>

## Three useful commands

- **run** — send a prompt through a profile into a session, with logs and transcript; add `--background` to return attach handles without waiting for transcript collection, or `--interactive --background` to launch an attachable human-present sibling desk.
- **ping** — a deterministic `DRONE_ACK <session>` smoke test wrapped around `run`.
- **bench** — repeated `ping` runs with `--count` / `--parallel` and timing stats. A harness check, not a swarm coordinator.

## Use from mise

For repos that want the released command on PATH, declare the shiv package. `latest` means the newest semver release, not default-branch code.

```toml
[plugins]
shiv = "https://github.com/KnickKnackLabs/vfox-shiv"

[tools]
"shiv:sphincters" = "latest"
```

## Development

Development pins `shiv:sessions = "0.4"`; interactive background desks need the persistent non-headless `sessions wake --message` semantics introduced in sessions v0.4.7. Tests use KKL BATS and Rush with a four-job default across and within files. Fixtures isolate mutable state per test; use `--jobs 1` for serial debugging.

```bash
gh repo clone KnickKnackLabs/sphincters
cd sphincters
mise trust
mise install

mise run test
mise run test run
mise run test --jobs 1
mise run lint
mise exec -- readme build --check
```

This README is generated from `README.tsx`. The test count is computed when the README is built.

---

<div align="center">

Related tools: [sessions](https://github.com/KnickKnackLabs/sessions), [desks](https://github.com/KnickKnackLabs/desks), and [shiv](https://github.com/KnickKnackLabs/shiv).

</div>
