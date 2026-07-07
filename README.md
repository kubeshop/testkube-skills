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

The four skills fall into two groups: **setup** (get a working CLI + environment)
and the **core chain** (author → run).

```
  SETUP                              CORE CHAIN
  ─────                              ──────────

installing-testkube-cli        testworkflow-author        testworkflow-runner
        │                            │                             │
        │ install / verify CLI       │ write + validate YAML       │ run + diagnose
        ▼                            │                             │
installing-testkube-oss-agent        ▼                             ▼
        │ spin up an environment  workflow.yaml ──────────►  execution logs
        │ to run against                                           │
        └──────── prerequisites for ────► the core chain          ▼
                                                            root cause report
```

First get the tooling ready — `installing-testkube-cli` ensures the `testkube`
command exists, and `installing-testkube-oss-agent` gives you an environment to
run against (skip it if you already have a Testkube Cloud or OSS environment).
Then the core chain runs: authoring produces a runnable TestWorkflow, and the
runner executes it and reports back.

## Installation

Copy the skill directories to your agent's skills folder:

**Claude Code:**
```bash
cp -r skills/installing-testkube-cli ~/.claude/skills/
cp -r skills/installing-testkube-oss-agent ~/.claude/skills/
cp -r skills/testworkflow-author ~/.claude/skills/
cp -r skills/testworkflow-runner ~/.claude/skills/
```

**VS Code / GitHub Copilot:**
```bash
cp -r skills/installing-testkube-cli .github/skills/
cp -r skills/installing-testkube-oss-agent .github/skills/
cp -r skills/testworkflow-author .github/skills/
cp -r skills/testworkflow-runner .github/skills/
```

## Usage

Invoke a skill directly:

```
/installing-testkube-cli Install the Testkube CLI if it isn't already present
/installing-testkube-oss-agent Spin up a local OSS Testkube environment
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
