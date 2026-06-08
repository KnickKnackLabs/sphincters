/** @jsxImportSource jsx-md */

import { readFileSync, readdirSync, existsSync } from "fs";
import { join, resolve } from "path";
import {
  Heading, Paragraph, CodeBlock, LineBreak, HR,
  Bold, Code, Link,
  Badge, Badges, Center, Section, Details,
  List, Item,
  Raw,
} from "readme";

const ROOT = resolve(import.meta.dirname);
const TASK_DIR = join(ROOT, ".mise/tasks");
const TEST_DIR = join(ROOT, "test");

const workerTasks = ["run", "ping", "bench"].filter((task) =>
  existsSync(join(TASK_DIR, task))
);

const testFiles = readdirSync(TEST_DIR).filter((f) => f.endsWith(".bats"));
const testSrc = testFiles
  .map((f) => readFileSync(join(TEST_DIR, f), "utf-8"))
  .join("\n");
const testCount = [...testSrc.matchAll(/@test "/g)].length;

const boundaryDiagram = [
  "                 sphincters run",
  "                       │",
  "                       ▼",
  "             ┌──────────────────┐",
  "             │ launch profile   │  cwd / system prompt / env scrub / meta",
  "             └─────────┬────────┘",
  "                       │ profile.json",
  "                       ▼",
  "  prompt.md ──▶ sessions new ──▶ sessions wake [--headless] ──▶ sessions read",
  "                       │                    │                       │",
  "                       │                    │                       └─ skipped with --background",
  "                       └────────────────────┴───────────────────────┘",
  "                                            ▼",
  "          logs + transcript/result JSON + optional attach handles",
].join("\n");

const artifactTree = [
  "exports/first-run/",
  "├── sphincters-run-plain-...prompt.md",
  "├── sphincters-run-plain-...profile.json",
  "├── plain-system-prompt.md",
  "├── sphincters-run-plain-...new.log",
  "├── sphincters-run-plain-...wake.log",
  "├── sphincters-run-plain-...read.log",
  "├── sphincters-run-plain-...transcript.txt",
  "└── sphincters-run-plain-...result.json",
].join("\n");

const profileJson = `{
  "version": 1,
  "profile": {"name": "plain", "kind": "plain", "subject": "drone"},
  "cwd": "/tmp/sphincters-run/cwd",
  "system_prompt_file": "/tmp/sphincters-run/plain-system-prompt.md",
  "identity": {"mode": "skip"},
  "unset_env": ["GH_TOKEN", "GITHUB_TOKEN", "CHAT_IDENTITY"],
  "meta": {"drone.profile": "plain"}
}`;

const readme = (
  <>
    <Center>
      <Raw>{`<p align="center"><img src="assets/hero.png" alt="Sphincters mascot" width="360" /></p>\n\n`}</Raw>

      <Heading level={1}>sphincters</Heading>

      <Paragraph>
        <Bold>Launch worker sessions through profiles and keep their records inspectable.</Bold>
      </Paragraph>

      <Paragraph>
        <Code>sphincters</Code> wraps session launch patterns in a small,
        profile-driven interface. It records prompts, profile specs, logs,
        transcripts, and result JSON so a parent process can inspect the run
        later.
      </Paragraph>

      <Badges>
        <Badge label="lang" value="bash" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tests" value={`${testCount} passing`} color="brightgreen" href="test/" />
        <Badge label="workers" value={`${workerTasks.length} commands`} color="blue" />
        <Badge label="install" value="shiv" color="orange" />
      </Badges>
    </Center>

    <LineBreak />

    <Section title="Quick start">
      <CodeBlock lang="bash">{`# Install the latest released sphincter
shiv install sphincters

# Check the plumbing without launching a model
sphincters ping --dry-run --model fake/model --json

# Start a worker session
sphincters run \\
  --profile plain \\
  --model openai-codex/gpt-5.5 \\
  --prompt-file task.md \\
  --out-dir exports/first-run \\
  --json

# Start a non-blocking same-agent sibling and return attach handles
sphincters run \\
  --profile sibling \\
  --background \\
  --model openai-codex/gpt-5.5 \\
  --prompt-file handoff.md \\
  --json

# Start an interactive same-agent sibling desk for live attach
sphincters run \\
  --profile sibling \\
  --interactive \\
  --background \\
  --model openai-codex/gpt-5.5 \\
  --prompt-file handoff.md \\
  --json

# Run repeated smoke checks
sphincters bench --model openai-codex/gpt-5.5 --count 3 --parallel 1 --json`}</CodeBlock>
    </Section>

    <Section title="What it is">
      <Paragraph>
        <Code>sphincters</Code>
        {" is a small runner for worker sessions. The runner owns "}
        <Code>sessions new</Code>
        {", "}
        <Code>sessions wake</Code>
        {", "}
        <Code>sessions read</Code>
        {", logging, and result JSON. Runs are headless by default; "}
        <Code>--interactive</Code>
        {" wakes a human-present session instead. With "}
        <Code>--background</Code>
        {", the runner skips the blocking read step and returns attach/read handles instead. Profiles describe how the worker should be launched."}
      </Paragraph>

      <CodeBlock>{boundaryDiagram}</CodeBlock>

      <Paragraph>
        The core abstraction is worker/profile/session. A profile can describe
        a plain model call today and can later describe an agent identity,
        long-running process, or re-wake policy without changing the runner's
        record format.
      </Paragraph>
    </Section>

    <Section title="Run modes">
      <Paragraph>
        <Code>sphincters run</Code>
        {" has two separate axes: session mode and process mode. Runs are "}
        <Bold>headless</Bold>
        {" by default; "}
        <Code>--interactive</Code>
        {" makes the session human-present. Runs are "}
        <Bold>foreground</Bold>
        {" by default; "}
        <Code>--background</Code>
        {" launches through shell/zmx and returns handles."}
      </Paragraph>

      <Raw>{`| Command shape | What happens | Use when |
| --- | --- | --- |
| \`sphincters run ...\` | Headless foreground run; waits, then collects transcript. | One bounded worker answer now. |
| \`sphincters run --background ...\` | Headless background run; returns attach/status/wait/read handles and skips transcript collection. | A sibling scout or worker should run while the parent continues. |
| \`sphincters run --interactive --background ...\` | Interactive background session; returns an attachable desk handle. | Or or a lead agent may join the sibling and talk. |
| \`sphincters run --interactive ...\` | Interactive foreground session; requires a TTY and blocks until it exits. | A human intentionally starts sphincters from a terminal and wants to enter that session immediately. |

Foreground interactive mode fails loudly without a TTY. Agents should normally use \`--interactive --background\` for attachable sibling desks.

`}</Raw>
    </Section>

    <Section title="Run records">
      <Paragraph>
        Every run writes a directory that a human or parent process can inspect.
        If a worker failed, the logs are already separated by phase. If it
        succeeded, the transcript and result JSON point at each other.
      </Paragraph>

      <CodeBlock>{artifactTree}</CodeBlock>
    </Section>

    <Section title="Profiles are launch adapters">
      <Paragraph>
        A profile is an executable under <Code>profiles/</Code> or{" "}
        <Code>SPHINCTERS_PROFILE_PATH</Code>. It prepares launch context and
        prints a JSON spec. The built-in <Code>plain</Code> profile creates a
        stateless system prompt and scrubs ambient identity and common
        side-effect credentials before waking. The built-in <Code>sibling</Code>{" "}
        profile preserves inherited agent identity, defaults to the caller cwd,
        and frames the launched session as same-agent sibling/continuation work
        rather than a subordinate worker.
      </Paragraph>

      <Details summary="Profile JSON contract">
        <CodeBlock lang="json">{profileJson}</CodeBlock>
      </Details>
    </Section>

    <Section title="Three useful commands">
      <List>
        <Item>
          <Bold>run</Bold>
          {" — send a prompt through a profile into a session, with logs and transcript; add "}
          <Code>--background</Code>
          {" to return attach handles without waiting for transcript collection, or "}
          <Code>--interactive --background</Code>
          {" to launch an attachable human-present sibling desk."}
        </Item>
        <Item>
          <Bold>ping</Bold>
          {" — a deterministic "}
          <Code>DRONE_ACK &lt;session&gt;</Code>
          {" smoke test wrapped around "}
          <Code>run</Code>
          {"."}
        </Item>
        <Item>
          <Bold>bench</Bold>
          {" — repeated "}
          <Code>ping</Code>
          {" runs with "}
          <Code>--count</Code>
          {" / "}
          <Code>--parallel</Code>
          {" and timing stats. A harness check, not a swarm coordinator."}
        </Item>
      </List>
    </Section>

    <Section title="Use from mise">
      <Paragraph>
        For repos that want the released command on PATH, declare the shiv
        package. <Code>latest</Code> means the newest semver release, not
        default-branch code.
      </Paragraph>

      <CodeBlock lang="toml">{`[plugins]
shiv = "https://github.com/KnickKnackLabs/vfox-shiv"

[tools]
"shiv:sphincters" = "latest"`}</CodeBlock>
    </Section>

    <Section title="Development">
      <CodeBlock lang="bash">{`gh repo clone KnickKnackLabs/sphincters
cd sphincters
mise trust
mise install

mise run test
mise run lint
mise exec -- readme build --check`}</CodeBlock>

      <Paragraph>
        This README is generated from <Code>README.tsx</Code>. The test count
        is computed when the README is built.
      </Paragraph>
    </Section>

    <HR />

    <Center>
      <Paragraph>
        Related tools: <Link href="https://github.com/KnickKnackLabs/sessions">sessions</Link>
        {" and "}
        <Link href="https://github.com/KnickKnackLabs/shiv">shiv</Link>.
      </Paragraph>
    </Center>
  </>
);

console.log(readme);
