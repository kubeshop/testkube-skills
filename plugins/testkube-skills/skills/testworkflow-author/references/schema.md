# TestWorkflow Schema Reference

How the TestWorkflow YAML is organized and how to use it effectively. For the
complete annotated field listing, load `assets/workflow-schema.yaml` (workflows)
or `assets/template-schema.yaml` (templates).

## Structure Overview

Every TestWorkflow has four top-level areas under `spec`:

| Area | Purpose | Key Question It Answers |
|------|---------|------------------------|
| `spec.content` | Where the test code comes from | "What code are we testing?" |
| `spec.container` | Default container settings | "What environment runs this?" |
| `spec.steps` | What to actually execute | "How do we run the test?" |
| `spec.config` / `spec.events` / `spec.pod` | Configuration, triggers, pod tuning | "How is it scheduled and configured?" |

## Content Sources

### `spec.content.files` — Inline scripts

Embed test code directly in the workflow. Best for short scripts, config files,
or when you don't have a Git repository.

```yaml
content:
  files:
  - path: /data/test.js
    content: |
      import http from 'k6/http';
      export default function() { http.get('https://test.k6.io'); }
```

Relative paths resolve against the container's working directory. Use `/data/`

### `spec.content.files[].contentFrom` — Secret/ConfigMap files

Mount Kubernetes Secrets or ConfigMaps as files instead of inline content:

```yaml
content:
  files:
  - path: /etc/ssl/certs/ca.crt
    contentFrom:
      secretKeyRef:
        name: tls-certs
        key: ca.crt
```

Use `contentFrom` for TLS certificates, license keys, or config files managed
outside the workflow.
for absolute paths that work regardless of `workingDir`.

### `spec.content.git` — Repository checkout

Clone a Git repository. Default mount: `/data/repo`. Testkube handles the clone
automatically — no `git clone` commands needed in your steps.

```yaml
content:
  git:
    uri: https://github.com/org/repo
    revision: main
    paths:
    - tests/playwright/
```

Key fields:
- `uri` — repository URL (HTTPS or SSH)
- `revision` — branch, tag, or commit SHA
- `paths` — sparse checkout (only fetch these directories)
- `token` / `sshKey` / `username` — authentication for private repos
- `tokenFrom` / `sshKeyFrom` / `usernameFrom` — Kubernetes Secret references (preferred over inline)

## Container Defaults

`spec.container` sets defaults for ALL steps. Individual steps can override
with their own `container`.

Most-used fields:

| Field | Purpose | Default |
|-------|---------|---------|
| `image` | Container image | Required — no default |
| `resources.requests` | Guaranteed CPU/memory | None — always set |
| `resources.limits` | Maximum CPU/memory | None |
| `workingDir` | Working directory | Image WORKDIR |
| `env` | Environment variables | None |
| `command` / `args` | Override entrypoint | Image ENTRYPOINT/CMD |

## Step Anatomy

A step can have up to 25 properties but most workflows use only a handful.
The most commonly used:

| Property | Type | Purpose |
|----------|------|---------|
| `name` | string | Human-readable step name |
| `shell` | string | Inline shell command (simplest) |
| `run` | object | Run with custom image/env/resources |
| `execute` | object | Run other workflows or tests |
| `template` | object | Use a TestWorkflowTemplate |
| `use` | array | Include template defaults |
| `parallel` | object | Matrix or sharded execution |
| `artifacts` | object | Collect output files |
| `condition` | string | When to run: "passed", "failed", "always" |
| `optional` | bool | Failure doesn't fail the workflow |
| `timeout` | string | Max step duration ("5m", "30s") |
| `retry` | object | Auto-retry on failure |
| `delay` | string | Wait before step ("30s") |
| `paused` | bool | Halt for manual approval |
| `pure` | bool | Prevents container merging — use for dependency install steps |
| `steps` | array | Nested sub-steps |

Load `assets/workflow-schema.yaml` for the complete field listing with types
and descriptions.

## Step Type Deep Dive

### `shell` — Simplest step

A single shell command using the default container image. Auto-prepends
`set -e` to fail on first error.

```yaml
steps:
- name: Run tests
  shell: npm test
```

### `run` — Custom container per step

Use a different image, set step-specific environment variables, or define
custom command/args.

```yaml
steps:
- name: Lint Go code
  run:
    image: golang:1.26-bookworm
    shell: golangci-lint run ./...
    env:
    - name: GOFLAGS
      value: "-mod=readonly"
```

### `execute` — Run other Testkube resources

Compose workflows and tests by name.

```yaml
steps:
- execute:
    parallelism: 2
    workflows:
    - name: playwright-smoke
    - name: cypress-smoke
```

### `template` — Reuse a TestWorkflowTemplate

Use a predefined template with configuration parameters.

```yaml
steps:
- template:
    name: official/k6
    config:
      version: "0.49.0"
      duration: "30s"
```

### `parallel` — Matrix or sharding

Run the same step with different parameters or split across shards.

```yaml
steps:
- parallel:
    count: 5
    run:
      image: grafana/k6:latest
      shell: k6 run test.js
```

## Config & Expressions

`spec.config` defines parameterized inputs. Values are referenced with
`{{ config.paramName }}` in most string fields.

```yaml
spec:
  config:
    VUS:
      type: integer
      default: 5
    targetUrl:
      type: string
      default: "https://test.k6.io"
  steps:
  - shell: k6 run -e URL={{ config.targetUrl }} --vus {{ config.VUS }} test.js
```

Config types: `string`, `integer`, `boolean`. Each parameter can have a
`default`, `description`, and optionally `required: true`.

Other expression helpers:
- `{{ services.name.0.ip }}` — reference companion service IPs
- `{{ shellquote(env.VAR) }}` — safely quote env var for shell
- `{{ env.VAR }}` — raw env var value

### Dynamic image tags

Expressions can build image names dynamically:

```yaml
container:
  image: mcr.microsoft.com/playwright:v{{ config.version }}
```

### Expression conditions

Beyond `"passed"`/`"failed"`/`"always"`, conditions accept full expressions:

```yaml
- name: Run only when needed
  condition: config.workers > 1 || config.force
  shell: echo "Running with {{ config.workers }} workers"
```

### Secret references

Use `secret()` for Kubernetes Secrets when you need the value in `{{ }}` expressions:

```yaml
env:
- name: API_TOKEN
  value: '{{ secret("my-secret", "token") }}'
```

### Credential references

Use `credential()` for Testkube-managed credentials (Dashboard → Settings).
Credentials are scoped at org, environment, or workflow level:

```yaml
env:
- name: API_KEY
  value: '{{ credential("my-api-key") }}'
- name: BASE_URL
  value: '{{ credential("staging-base-url") }}'
```

Prefer `credential()` over `secret()` when using the Testkube Control Plane —
credentials are managed in the Dashboard, encrypted at rest, and never exposed
in YAML.

### Global environment variables

Standard `env` entries are only visible to the main container. Add `global: true`
to propagate a variable to services and parallel workers:

```yaml
container:
  env:
  - name: TARGET_URL
    value: "https://staging.example.com"
    global: true
```

### Math and functions

Expressions support arithmetic (`{{ config.workers * 5 }}`), string manipulation
(`split()`, `join()`), JSON parsing (`json()`, `tojson()`), and 30+ built-in
functions. See the full reference:

**See**: https://docs.testkube.io/articles/test-workflows-expressions

## Events

Schedule workflows with CronJob syntax:

```yaml
spec:
  events:
  - cronjob:
      cron: "0 * * * *"  # every hour
      timezone: "Europe/Warsaw"  # optional, defaults to UTC
```

## Pod & Job Tuning

Key settings for controlling execution behavior:

| Field | Purpose |
|-------|---------|
| `spec.job.activeDeadlineSeconds` | Workflow-level timeout |
| `spec.pod.activeDeadlineSeconds` | Pod-level timeout |
| `spec.pod.imagePullSecrets` | Private registry credentials |
| `spec.pod.serviceAccountName` | Pod identity for RBAC |
| `spec.pod.nodeSelector` | Schedule on specific nodes |
| `spec.pod.labels` | Kubernetes labels on the pod |
| `spec.system.isolatedContainers` | Disable container merging |
| `spec.execution.silent` | Suppress webhooks, insights, metrics for utility workflows |
| `steps[].negative` | Invert pass/fail — non-zero exit becomes success (error testing) |

## TestWorkflowTemplate Differences

TestWorkflowTemplates follow the same schema with two differences:

1. `kind: TestWorkflowTemplate` — different Kubernetes resource
2. **No `use` inheritance** — templates cannot include other templates

Templates are designed to be reusable building blocks. They define defaults
(steps, container, content) and config parameters. Workflows that `use` or
`template` them inherit these defaults in scope-dependent ways (see Gotchas
in SKILL.md for template inlining scopes).

Load `assets/template-schema.yaml` for the complete template field listing.
