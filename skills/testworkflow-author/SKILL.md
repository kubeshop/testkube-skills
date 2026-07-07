---
name: testworkflow-author
description: >
  Create and validate Testkube TestWorkflow YAML files. Use when writing test workflow YAML, choosing step types, or
  when the user asks to create a Testkube TestWorkflow. Covers shell steps, container run steps, execute composition,
  templates, services, artifacts, config parameters, and cron triggers. Does NOT run workflows — that is the
  testworkflow-runner skill's responsibility.
metadata:
  initiative: test-authoring
---

# testworkflow-author

Create and validate Testkube TestWorkflow YAML files. This skill writes the workflow and validates its schema. It does
NOT run the workflow or analyze execution results — the `testworkflow-runner` skill handles that.

Write files in the current working directory. Default to the filename `testworkflow.yaml` unless a different path is
specified. Do not invent credentials, secrets, tokens, or private URLs — if you need them, describe what you need in
your final message (see Credentials below).

## The Core Loop

Every TestWorkflow task follows this sequence:

1. **Review context** — check for context from previous steps (what tool was chosen, what version, how to run it, what
   files exist).
2. **Gather requirements** — test tool, environment variables, expected artifacts, resource needs.
3. **Read dependency files** — read the lock file (package-lock.json, go.sum, poetry.lock, Gemfile.lock, pom.xml) to
   determine exact resolved versions. If no lock file exists, read the manifest (package.json, go.mod, etc.)
4. **Read schema** — load `references/schema.md` with the `read` tool (Rule 7)
5. **Choose step types** — use the Decision Tree and Step Type Guide below
6. **Write the YAML** — load a matching example from `examples/` as your starting template (e.g.
   `examples/playwright-git.yaml` for Playwright, `examples/go-build-lint.yaml` for Go,
   `examples/k6-inline.yaml` for K6)
7. **Validate** — `testkube create testworkflow --dry-run -f <file>`
8. **Fix and re-validate** — address every validation error before proceeding

## Credentials

When the workflow requires credentials, tokens, or secrets you do not have, describe what you need clearly in your final
message. Do not guess or use placeholder values. The credential will be provided on your next invocation.

### How to reference credentials in workflows

Use Testkube-managed `credential()` expressions:

```yaml
env:
  - name: API_KEY
    value: '{{ credential("my-api-key") }}'
```

Or Kubernetes Secret references:

```yaml
env:
  - name: API_TOKEN
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: token
```

If you don't know the credential name, say what you need in your response and it will be provided.

## Rules

These are mandatory. Violating any rule produces a broken workflow.

1. **MUST install dependencies in a separate step.** If the project has a dependency manifest (package.json, go.mod,
   requirements.txt, Gemfile, pom.xml, build.gradle), add a dedicated install step BEFORE the test step. Never assume
   dependencies are pre-installed in the container image. Example: `npm ci`, `go mod download`,
   `pip install -r requirements.txt`.

2. **MUST read the lock file to determine resolved versions.** Semver ranges in manifests (`^1.52.0`, `~2.3`, `>=1.0`)
   do NOT tell you what version gets installed. Read package-lock.json, go.sum, poetry.lock, Gemfile.lock to find the
   actual resolved version. If no lock file exists, run the install command and check what was resolved, or use the
   latest stable image for the tool.

3. **MUST match the container image tag to the resolved dependency version.** The image tag must match the major.minor
   version from the lock file. Example: if package-lock.json resolves `@playwright/test` to `1.61.1`, use image
   `mcr.microsoft.com/playwright:v1.61.1-noble`. A mismatch causes `browserType.launch: Executable doesn't exist` or
   equivalent errors.

4. **MUST use `npx`/equivalent for locally-installed CLI tools.** After `npm ci`, binaries are in `node_modules/.bin/`,
   not on PATH. Run tools via `npx <tool>` (Node.js), `python -m <module>` (Python), or the built binary path (Go).
   Never assume a tool is globally available just because its package is installed.

5. **MUST set `condition: always` on artifact collection steps.** Artifacts (reports, screenshots, traces) are most
   valuable when tests fail. Without `condition: always`, the artifact step is skipped on failure — exactly when you
   need it most.

6. **MUST understand that `--dry-run` validates schema only.** A passing dry-run means the YAML structure is valid. It
   does NOT mean the workflow will succeed at runtime. Missing dependencies, wrong image versions, and incorrect
   commands all pass dry-run without error.

7. **MUST read `references/schema.md` before writing any YAML.** This reference covers the most-used fields
   with examples. Load it with the `read` tool before starting to write. Do not rely on memory alone.

## Decision Tree

### Choosing a step type

```
Need to run a test?
├── Single command, default image?
│   └── shell step (simplest)
├── Different image or custom env per step?
│   └── run step
├── Reuse an existing pattern (official/community template)?
│   └── template step
├── Compose multiple existing workflows or tests?
│   └── execute step
├── Run same test with varying parameters (matrix/shard)?
│   └── parallel step
├── Need a companion service (database, Selenium, Docker-in-Docker)?
│   └── services
└── Need pre/post cleanup that always runs?
    └── setup / after
```

## Schema Quick Reference

The 15 most-used spec fields. See `references/schema.md` for the full schema.

| Field                       | Purpose                            | Example                                 |
| --------------------------- | ---------------------------------- | --------------------------------------- |
| `spec.content`              | Where test code comes from         | `{git: {uri, revision}}` or `{files}`   |
| `spec.container.image`      | Default container image for steps  | `"node:22"`                             |
| `spec.container.resources`  | CPU/memory requests and limits     | `{requests: {cpu: 128m, memory: 128Mi}}`|
| `spec.container.workingDir` | Working directory for all steps    | `"/data/repo"`                          |
| `spec.steps[].shell`        | Inline shell command (simplest)    | `"npm test"`                            |
| `spec.steps[].run`          | Step with custom container/image   | `{image, shell, env}`                   |
| `spec.steps[].execute`      | Run other workflows or tests       | `{workflows: [{name}]}`                 |
| `spec.steps[].template`     | Use a TestWorkflowTemplate         | `{name: "official/k6", config: {...}}`  |
| `spec.steps[].parallel`     | Parallel matrix or sharding        | `{count: 5}`                            |
| `spec.steps[].artifacts`    | Collect output files               | `{paths: ["**/*"]}`                     |
| `spec.config`               | Parameterized inputs for workflow  | `{VUS: {type: integer, default: 5}}`    |
| `spec.events`               | CronJob triggers                   | `[{cronjob: {cron: "0 * * * *"}}]`      |
| `spec.services`             | Sidecar containers (DB, Selenium)  | `{chrome: {image, readinessProbe}}`     |
| `spec.setup` / `spec.after` | Pre/post hooks, same as steps      | `setup: [{shell: "..."}]`               |

## CLI Quick Start

Commands for authoring. Full flags: `references/cli-reference.md`.

```bash
# Validate a workflow (schema check only — does NOT guarantee runtime success)
testkube create testworkflow --dry-run -f workflow.yaml

# Create a workflow (use --update if it already exists)
testkube create testworkflow -f workflow.yaml
testkube create testworkflow --update -f workflow.yaml

# Inspect a workflow definition
testkube get testworkflow <name>
```

Note: Running workflows and reading execution logs is the `testworkflow-runner` skill's job, not yours.

## Step Type Decision Guide

Detailed patterns with YAML examples: `references/step-patterns.md`.

| Step Type    | Use When                        | Key Fields                            | Example Scenario                               |
| ------------ | ------------------------------- | ------------------------------------- | ---------------------------------------------- |
| **shell**    | Single command, default image   | `shell`                               | "Run npm test in the default Playwright image" |
| **run**      | Different image/env per step    | `run: {image, shell, env, resources}` | "Lint Go code with golang:1.26 image"          |
| **execute**  | Run existing Testkube resources | `execute: {workflows, tests}`         | "Orchestrate a test suite of 3 workflows"      |
| **template** | Reuse a TestWorkflowTemplate    | `template: {name, config}`            | "Use official/k6 template with custom VUS"     |
| **use**      | Include template defaults       | `use: [{name}]`                       | "Add close-istio sidecar template"             |
| **parallel** | Matrix or sharded execution     | `parallel: {count, shards, matrix}`   | "Run K6 with 5 VUs in parallel"                |

### Step nesting

Steps can be nested: a parent step with `steps:` runs its children sequentially within that step's container context.
Use nesting for logical grouping — install deps, run tests, save artifacts — within a single container image.

### Step ordering

Steps run sequentially by default. Use `condition` to control when a step runs (`"passed"`, `"failed"`, `"always"`). Use
`optional: true` for non-critical steps whose failure should not fail the workflow.

## Gotchas

Environment-specific facts that defy reasonable assumptions.

- **Container merging**: By default, multiple simple steps may merge into one container for efficiency. Use
  `spec.system.isolatedContainers: true` for full isolation between steps.
- **Init containers**: Steps execute as init containers sequentially; the last step runs as the main container. Sidecar
  containers injected by operators (Istio, Linkerd) may not be available to init containers.
- **workingDir resolution**: Relative paths resolve against the container's WORKDIR, not the workflow root. Set
  `workingDir` explicitly to the directory where your test code lives.
- **Artifact paths**: Relative artifact paths resolve against the step's `workingDir`. Use absolute paths
  (`/data/artifacts/**`) to avoid ambiguity.
- **`{{ }}` expressions**: Usable in most string fields. `{{ config.param }}` for config values,
  `{{ services.name.0.ip }}` for service IPs, `{{ shellquote(env.VAR) }}` for safe shell quoting of env vars.
- **Image pull**: Images must come from a container registry — local images are not supported. Private registries
  require `imagePullSecrets` in `spec.pod`.
- **`activeDeadlineSeconds`**: Without this, a stuck workflow runs until the cluster kills it. Set in `spec.job` for
  workflow-level timeout, or `spec.pod` for per-pod limits.
- **Template inlining**: Templates are expanded before execution. `use` at top-level shares defaults across all steps;
  `use` at step-level scopes defaults to that step only; `template` at step-level is fully isolated.
- **`shell` auto-prepends `set -e`**: The shell step type exits on the first failing command by default. Use `run.shell`
  if you need more control over error handling behavior.
- **Playwright images**: Use `mcr.microsoft.com/playwright:v<VERSION>-noble` where `<VERSION>` matches the resolved
  `@playwright/test` version from the lock file. A bare `node` image will fail with
  `browserType.launch: Executable doesn't exist`. Check
  [Microsoft Artifact Registry](https://mcr.microsoft.com/en-us/product/playwright/about) for available tags.

## Validation Loop

Before finishing, always validate the schema:

```bash
# 1. Validate against the CRD schema
testkube create testworkflow --dry-run -f workflow.yaml

# 2. If validation fails, read the error message, fix the file, re-run step 1

# 3. Only proceed when dry-run passes
```

Never skip validation. A YAML that looks correct can still fail schema checks (missing required fields, wrong types,
invalid enum values). Remember: dry-run validates structure only — it cannot catch runtime errors like missing
dependencies or image version mismatches (see Rule 6).

## Reference Index

Load these files on demand — when the task calls for them.

| Reference                        | When to Load                                              | Status    |
| -------------------------------- | --------------------------------------------------------- | --------- |
| `assets/workflow-schema.yaml`    | When needing every available field and description        | Available |
| `assets/template-schema.yaml`    | When authoring TestWorkflowTemplates                      | Available |
| `references/schema.md`           | When writing or editing any YAML field                    | Available |
| `references/cli-reference.md`    | When needing CLI flags for create/dry-run                 | Available |
| `references/step-patterns.md`    | When choosing between step types or seeking YAML snippets | Available |
| `references/docs-concepts.md`    | When a concept (templates, merging, artifacts) is unclear | Available |
| `references/examples-catalog.md` | When seeking real-world patterns by tool/pattern          | Available |
| `examples/*.yaml`                | When needing concrete, runnable examples                  | Available |
