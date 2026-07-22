# Testkube CLI Reference — TestWorkflows

Essential CLI commands for the TestWorkflow lifecycle. All commands assume
the Testkube CLI is installed and configured (`testkube login`).

## Create a Workflow

```bash
testkube create testworkflow [flags]
```

| Flag | Purpose | Example |
|------|---------|---------|
| `-f, --file` | Path to workflow YAML | `-f workflow.yaml` |
| `--name` | Override workflow name | `--name my-k6-test` |
| `--update` | Update if already exists | `--update` |
| `--dry-run` | Validate YAML without creating | `--dry-run` |

**Always validate before creating:**

```bash
testkube create testworkflow --dry-run -f workflow.yaml
testkube create testworkflow -f workflow.yaml
```

Create from stdin (pipe the YAML):

```bash
cat workflow.yaml | testkube create testworkflow
```

## Run a Workflow

```bash
testkube run testworkflow <name> [flags]
```

| Flag | Purpose | Example |
|------|---------|---------|
| `-f, --watch` | Stream execution output | `-f` |
| `--config` | Override config parameters | `--config VUS=10` |
| `-v, --variable` | Pass execution variables | `-v ENV=staging` |
| `--target` | Target specific runner agents | `--target name=staging-runner` |
| `--target-not` | Exclude runner agents | `--target-not name=prod-runner` |
| `--target-replicate` | Replicate across runners | `--target-replicate region=eu` |
| `-d, --download-artifacts` | Download artifacts after run | `-d` |
| `--download-dir` | Artifact download directory | `--download-dir ./results` |
| `--format` | Artifact storage format | `--format archive` |
| `--mask` | Regex filter for artifacts | `--mask '.*\.xml$'` |
| `--tag` | Add execution tags | `--tag env=staging` |
| `-l, --label` | Select workflows by label | `-l tool=k6` |
| `--silent` | Disable webhooks/insights/metrics | `--silent` |
| `--name` | Custom execution name | `--name smoke-test-run-1` |
| `--service-name` | Target specific service | `--service-name postgres` |
| `--service-index` | Target service by index | `--service-index 0` |
| `--parallel-step-name` | Target parallel step by name | `--parallel-step-name shard-1` |
| `--parallel-step-index` | Target parallel step by index | `--parallel-step-index 0` |

Common run pipeline:

```bash
testkube create testworkflow -f workflow.yaml
testkube run testworkflow my-test -f
```

Run with config overrides and download artifacts:

```bash
testkube run testworkflow my-test -f --config VUS=10 --config duration=30s -d
```

## List and Inspect

List all workflows:

```bash
testkube get testworkflow
```

Inspect a specific workflow (shows YAML definition):

```bash
testkube get testworkflow my-test
```

Get execution details and logs:

```bash
# List recent executions for a workflow
testkube get testworkflowexecution

# Get details for a specific execution
testkube get testworkflowexecution <execution-id>

# Get only logs (skip execution details)
testkube get testworkflowexecution <execution-id> --logs-only
```

## Delete

```bash
testkube delete testworkflow <name>
```

Delete all workflows (destructive):

```bash
testkube delete testworkflow --all
```

## Abort

Stop a running execution:

```bash
testkube abort testworkflow <name>
```

## Templates

Create a TestWorkflowTemplate:

```bash
testkube create testworkflowtemplate -f template.yaml --name my-template --dry-run
testkube create testworkflowtemplate -f template.yaml --name my-template
```

List templates:

```bash
testkube get testworkflowtemplate
```

## Retrieve Artifacts

Download artifacts from a completed execution:

```bash
testkube download artifacts <execution-id> [flags]
```

| Flag | Purpose | Example |
|------|---------|---------|
| `--download-dir` | Download directory | `--download-dir ./results` |
| `--mask` | Regex filter for artifact files | `--mask '.*\.xml$'` |
| `-e, --execution-id` | Execution ID (alternative to positional) | `-e <id>` |

Download all artifacts:

```bash
testkube download artifacts <execution-id> --download-dir ./results
```

Download only JUnit XML reports:

```bash
testkube download artifacts <execution-id> --mask '.*\.xml$'
```

## Common Pipelines

**Create, validate, run:**

```bash
testkube create testworkflow --dry-run -f workflow.yaml
testkube create testworkflow -f workflow.yaml
testkube run testworkflow my-test -f
```

**Run, watch, download artifacts:**

```bash
testkube run testworkflow my-test -f -d --download-dir ./results
```

**Debug (validate only, don't create):**

```bash
testkube create testworkflow --dry-run -f workflow.yaml
```
