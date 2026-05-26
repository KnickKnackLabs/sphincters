<div align="center">

<p align="center"><img src="assets/hero.jpg" alt="A tired cartoon sphincter mascot" width="360" /></p>

# sphincters

**Run one bounded worker, then leave the evidence behind.**

A sphincter is a boundary. This one tightens around a prompt, a launch profile, and a single headless session so the parent process gets a clean artifact trail instead of a mysterious background swarm.

![lang: bash](https://img.shields.io/badge/lang-bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 14 passing](https://img.shields.io/badge/tests-14%20passing-brightgreen?style=flat)](test/)
![workers: 3 commands](https://img.shields.io/badge/workers-3%20commands-blue?style=flat)
![release: v0.1.0](https://img.shields.io/badge/release-v0.1.0-orange?style=flat)

</div>

<br />

## Quick start

```bash
# Install the latest released sphincter
shiv install sphincters

# Check the plumbing without launching a model
sphincters ping --dry-run --model fake/model --json

# Run one bounded worker
sphincters run \
  --profile plain \
  --model openai-codex/gpt-5.5 \
  --prompt-file task.md \
  --out-dir exports/first-run \
  --json

# Repeat the smallest smoke test
sphincters bench --model openai-codex/gpt-5.5 --count 3 --parallel 1 --json
```

## What it is

`sphincters` is a small runner for short-lived workers. The runner owns `sessions new`, `sessions wake --headless`, `sessions read`, logging, and result JSON. Profiles only describe how the worker should be launched.

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
                       └────────────────────┴────────────────────┘
                                            ▼
                 logs + transcript + result.json
```

The important distinction: the core abstraction is not "agent." It is worker/profile/session. A profile may launch an agent identity under the hood later, but the runner should not care.

## Artifacts, not vibes

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

A profile is an executable under `profiles/` or `SPHINCTERS_PROFILE_PATH`. It prepares launch context and prints a JSON spec. The built-in `plain` profile creates a stateless system prompt and scrubs ambient identity and common side-effect credentials before waking.

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

## Three useful motions

- **run** — one prompt through one profile into one session, with logs and transcript.
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

This README is generated from `README.tsx`. The test count and release badge are computed when the README is built.

---

<div align="center">

**Keep the boundary tight. Let the evidence out.**

[sessions](https://github.com/KnickKnackLabs/sessions) provides the transcript machinery; [shiv](https://github.com/KnickKnackLabs/shiv) installs the released command.

</div>
