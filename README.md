# Testkube Agent Skills

AI agent skills for [Testkube](https://testkube.io) — teach your AI agent how to
create, run, and debug test workflows on Kubernetes.

These skills follow the [Agent Skills](https://agentskills.io) open standard and
work with any compatible AI agent, including Claude Code, GitHub Copilot, and
VS Code agent mode.

## Skills

### installing-testkube-cli

**Use when:** the Testkube CLI is missing (`testkube: command not found`),
before running any skill that shells out to `testkube`, or when a specific CLI
version is required.

Installs, upgrades, or verifies the Testkube CLI (`testkube` / `tk` /
`kubectl-testkube`) on Linux, macOS, and Windows via the install script,
Homebrew, APT, Chocolatey, or a manual download.

> Checks for an existing installation first and reuses it, and installs only
> after confirming with the user — never reinstalls a working CLI.

### installing-testkube-oss-agent

**Use when:** you need a local Testkube OSS environment for testing and none is
running yet.

Sets up a local Testkube OSS standalone agent: checks prerequisites, creates a
cluster (k3d by default when a fresh local one is needed), and deploys the agent
into the `testkube` namespace. Standalone mode is CLI-driven (no dashboard).

> Detects an existing Testkube agent in the current cluster of any type
> (minikube, kind, k3d, remote) first and reuses it; installs missing pieces only
> after confirming each step with the user.

### test-discovery

**Use when:** a repository has been cloned locally and you need to know what
tests exist, what framework runs them, and what command executes them.

Walks a repo, detects language and framework from marker files (config,
manifest, lock files) and content signals, and groups findings into suites.
Every suite carries evidence + confidence, resolved framework version from lock
files, and a suggested container image. Handles polyglot monorepos, reports
ambiguity via `needs_input`, and never executes any test or install command.

> Emits one of two formats from the same walk: a **JSON manifest** for programs
> (the `testworkflow-author` skill, cloud-api ingestion, CI) and a
> **Markdown report** for a person to read — which also opens cleanly in any
> plain-text editor. JSON is the default; Markdown is emitted when the
> invocation asks for it or the output path ends in `.md`.

Output contract: single document to stdout — JSON by default (matching
[`plugins/testkube-skills/skills/test-discovery/assets/manifest-schema.json`](./plugins/testkube-skills/skills/test-discovery/assets/manifest-schema.json)),
or Markdown on request.

### testworkflow-author

**Use when:** creating a TestWorkflow YAML file, choosing step types, or writing
test workflow configuration.

Creates and validates Testkube TestWorkflow YAML files. Covers shell steps,
container run steps, execute composition, templates, services, artifacts, config
parameters, and cron triggers. Reads lock files to determine exact dependency
versions and matches container images to resolved versions. Validates every
workflow against the CRD schema before completion.

> Includes 22 worked examples covering Playwright, Cypress, k6, Go, JMeter,
> Postman, Selenium, Gradle, Maven, Artillery, Locust, Robot Framework, and
> more.

### testworkflow-runner

**Use when:** a TestWorkflow has been authored and needs to be executed, or a
previous execution failed and needs diagnosis.

Runs TestWorkflow executions, reads logs, and diagnoses failures. Covers the
full execution lifecycle: create, run, monitor, log retrieval, artifact download,
and root cause analysis. Includes a failure pattern reference table with exit
codes, symptoms, and recommended fixes.

> Does NOT edit workflow YAML — if the diagnosis indicates a configuration
> problem, it reports findings for `testworkflow-author` to fix.

## How they work together

The five skills fall into two groups: **setup** (get a working CLI + environment)
and the **core chain** (discover → author → run).

```
  SETUP                              CORE CHAIN
  ─────                              ──────────

installing-testkube-cli        test-discovery         testworkflow-author        testworkflow-runner
        │                            │                        │                          │
        │ install / verify CLI       │ walk repo, emit        │ write + validate YAML    │ run + diagnose
        ▼                            │ test-manifest.json     │                          │
installing-testkube-oss-agent        │                        │                          │
        │ spin up an environment     ▼                        ▼                          ▼
        │ to run against      test-manifest.json ─────►  workflow.yaml ──────────►  execution logs
        │                                                                                 │
        └──────────── prerequisites for ────────────► the core chain                     ▼
                                                                                   root cause report
```

First get the tooling ready — `installing-testkube-cli` ensures the `testkube`
command exists, and `installing-testkube-oss-agent` gives you an environment to
run against (skip it if you already have a Testkube Cloud or OSS environment).
Then the core chain runs: discovery reports what tests exist, authoring turns
that into a runnable TestWorkflow, and the runner executes it and reports back.

## Installation

Copy the skill directories to your agent's skills folder:

**Claude Code:**
```bash
cp -r plugins/testkube-skills/skills/installing-testkube-cli ~/.claude/skills/
cp -r plugins/testkube-skills/skills/installing-testkube-oss-agent ~/.claude/skills/
cp -r plugins/testkube-skills/skills/test-discovery ~/.claude/skills/
cp -r plugins/testkube-skills/skills/testworkflow-author ~/.claude/skills/
cp -r plugins/testkube-skills/skills/testworkflow-runner ~/.claude/skills/
```

**VS Code / GitHub Copilot:**
```bash
cp -r plugins/testkube-skills/skills/installing-testkube-cli .github/skills/
cp -r plugins/testkube-skills/skills/installing-testkube-oss-agent .github/skills/
cp -r plugins/testkube-skills/skills/test-discovery .github/skills/
cp -r plugins/testkube-skills/skills/testworkflow-author .github/skills/
cp -r plugins/testkube-skills/skills/testworkflow-runner .github/skills/
```

## Usage

Invoke a skill directly:

```
/installing-testkube-cli Install the Testkube CLI if it isn't already present
/installing-testkube-oss-agent Spin up a local OSS Testkube environment
/test-discovery Analyze the repository at /path/to/repo
/testworkflow-author Create a Playwright workflow for the login page
/testworkflow-runner Run the workflow and diagnose any failures
```

Or let the AI agent load them automatically — it matches your request to the
skill description and loads the relevant skill on demand.

### Claude Code (plugin)

```
/plugin marketplace add kubeshop/testkube-skills
/plugin install testkube-skills@testkube-skills
```

Skills are then invoked as `/testkube-skills:installing-testkube-cli`,
`/testkube-skills:installing-testkube-oss-agent`,
`/testkube-skills:test-discovery`,
`/testkube-skills:testworkflow-author`, and
`/testkube-skills:testworkflow-runner`, or auto-loaded when relevant.

### Codex (plugin)

Codex reads a repo marketplace from `.agents/plugins/marketplace.json` (this repo ships
one) and a per-plugin manifest from `plugins/testkube-skills/.codex-plugin/plugin.json`. From a clone of this repo,
enable the plugin with the Codex `/plugins` UI, or install it locally per the
[build guide](https://developers.openai.com/codex/plugins/build). Plugins cache under
`~/.codex/plugins/cache/testkube-skills/testkube-skills/local/`.

### Cursor (plugin)

This repo follows the official [cursor/plugin-template](https://github.com/cursor/plugin-template)
layout: a marketplace manifest at `.cursor-plugin/marketplace.json` lists the plugin, whose
own manifest lives at `plugins/testkube-skills/.cursor-plugin/plugin.json`. Point Cursor at
this repo/marketplace to install `testkube-skills`.

## Prerequisites

- Testkube CLI installed — the `installing-testkube-cli` skill will install it if it isn't already present (or install it manually per the [install docs](https://docs.testkube.io/articles/install))
- If using Testkube Cloud, authenticate with `testkube login`
- Access to a Testkube environment (open source or cloud) — the `installing-testkube-oss-agent` skill can spin up a local OSS one
- An AI agent that supports the [Agent Skills](https://agentskills.io) standard
