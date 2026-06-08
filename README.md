<div align="center">

<p align="center"><img src="assets/hero.png" alt="Sphincters mascot" width="360" /></p>

# sphincters

**Launch worker sessions through profiles and keep their records inspectable.**

`sphincters` wraps session launch patterns in a small, profile-driven interface. It records prompts, profile specs, logs, transcripts, and result JSON so a parent process can inspect the run later.

![lang: bash](https://img.shields.io/badge/lang-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 17 passing](https://img.shields.io/badge/tests-17%20passing-brightgreen?style=flat)](test/)
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

# Run repeated smoke checks
sphincters bench --model openai-codex/gpt-5.5 --count 3 --parallel 1 --json
```

## What it is

`sphincters` is a small runner for worker sessions. The runner owns `sessions new`, `sessions wake --headless`, `sessions read`, logging, and result JSON. With `--background`, the runner skips the blocking read step and returns attach/read handles instead. Profiles describe how the worker should be launched.

```
                 sphincters run
                       │
                       ▼
             ┌──────────────────┐
             │ launch profile   │  cwd / system prompt / env scrub / meta
             └─────────┬────────┘
                       │ profile.json
                       ▼
  prompt.md ──▶ sessions new ──▶ sessions wake --headless ──▶ sessions read
                       │                    │                    │
                       │                    │                    └─ skipped with --background
                       └────────────────────┴────────────────────┘
                                            ▼
          logs + transcript/result JSON + optional attach handles
```

The core abstraction is worker/profile/session. A profile can describe a plain model call today and can later describe an agent identity, long-running process, or re-wake policy without changing the runner's record format.

## Run records

Every run writes a directory that a human or parent process can inspect. If a worker failed, the logs are already separated by phase. If it succeeded, the transcript and result JSON point at each other.

```
exports/first-run/
├── sphincters-run-plain-...prompt.md
├── sphincters-run-plain-...profile.json
├── plain-system-prompt.md
├── sphincters-run-plain-...new.log
├── sphincters-run-plain-...wake.log
├── sphincters-run-plain-...read.log
├── sphincters-run-plain-...transcript.txt
└── sphincters-run-plain-...result.json
```

## Profiles are launch adapters

A profile is an executable under `profiles/` or `SPHINCTERS_PROFILE_PATH`. It prepares launch context and prints a JSON spec. The built-in `plain` profile creates a stateless system prompt and scrubs ambient identity and common side-effect credentials before waking. The built-in `sibling` profile preserves inherited agent identity, defaults to the caller cwd, and frames the launched session as same-agent sibling/continuation work rather than a subordinate worker.

<details>
<summary><b>Profile JSON contract</b></summary>

```json
{
  "version": 1,
  "profile": {"name": "plain", "kind": "plain", "subject": "drone"},
  "cwd": "/tmp/sphincters-run/cwd",
  "system_prompt_file": "/tmp/sphincters-run/plain-system-prompt.md",
  "identity": {"mode": "skip"},
  "unset_env": ["GH_TOKEN", "GITHUB_TOKEN", "CHAT_IDENTITY"],
  "meta": {"drone.profile": "plain"}
}
```

</details>

## Three useful commands

- **run** — send a prompt through a profile into a session, with logs and transcript; add `--background` to return attach handles without waiting for transcript collection.
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

```bash
gh repo clone KnickKnackLabs/sphincters
cd sphincters
mise trust
mise install

mise run test
mise run lint
mise exec -- readme build --check
```

This README is generated from `README.tsx`. The test count is computed when the README is built.

---

<div align="center">

Related tools: [sessions](https://github.com/KnickKnackLabs/sessions) and [shiv](https://github.com/KnickKnackLabs/shiv).

</div>
