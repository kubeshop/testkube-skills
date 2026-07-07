# TestWorkflow Step Patterns

Common patterns for building TestWorkflow steps, from simplest to most complex.
Each pattern is a minimal, working example. Patterns marked **(self-contained)**
can be validated with `--dry-run` on their own.

## Pattern 1: Simple Shell (self-contained)

**Use when**: A single command in the default container image is all you need.

```yaml
apiVersion: testworkflows.testkube.io/v1
kind: TestWorkflow
metadata:
  name: simple-shell
spec:
  container:
    image: alpine:latest
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
  steps:
  - name: Run command
    shell: echo "Hello from Testkube" && uname -a
```

## Pattern 2: Run with Custom Image

**Use when**: You need a different container image or environment per step.
The `run` field gives you full control over the container for that step.

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

The step runs in the `golang:1.26-bookworm` image regardless of what
`spec.container.image` is set to. All other steps use the default image.

> **Note**: This pattern shows only the step portion. Place it under
> `spec.steps:` of a complete workflow with `apiVersion`, `kind`, `metadata`,
> and `spec.container` defined.

## Pattern 3: Inline Content (self-contained)

**Use when**: Your test script is short and doesn't need a Git repository.
Embed it directly in the workflow under `spec.content.files`.

```yaml
apiVersion: testworkflows.testkube.io/v1
kind: TestWorkflow
metadata:
  name: inline-content
spec:
  content:
    files:
    - path: /data/test.js
      content: |
        import http from 'k6/http';
        export default function() { http.get('https://test.k6.io'); }
  container:
    image: grafana/k6:0.49.0
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
    workingDir: /data
  steps:
  - name: Run inline test
    shell: k6 run test.js --duration 5s
```

Relative paths in `files` resolve against the container's working directory.
Use `/data/` prefix for absolute paths that always work.

## Pattern 4: Git Checkout

**Use when**: Your test code lives in a Git repository. Testkube handles
the clone — no `git clone` commands needed.

```yaml
spec:
  content:
    git:
      uri: https://github.com/kubeshop/testkube
      revision: main
      paths:
      - test/k6/k6-smoke-test.js
  container:
    workingDir: /data/repo/test/k6
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
  steps:
  - name: Run test from repo
    run:
      image: grafana/k6:0.49.0
      shell: k6 run k6-smoke-test.js --duration 5s
```

The repo is cloned to `/data/repo` by default. Set `mountPath` to change
this. Use `paths` for sparse checkout — only those directories are fetched.
For private repos, add `token`/`sshKey` or their `*From` secret references.

## Pattern 5: Artifact Collection (self-contained)

**Use when**: Your test produces output files (reports, logs, screenshots)
that you want to save and view after execution.

```yaml
apiVersion: testworkflows.testkube.io/v1
kind: TestWorkflow
metadata:
  name: artifact-collection
spec:
  container:
    image: alpine:latest
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
  steps:
  - name: Generate output
    shell: mkdir -p /data/artifacts && echo "test results" > /data/artifacts/report.txt
  - name: Save artifacts
    condition: always
    artifacts:
      paths:
      - /data/artifacts/**
```

Key rules:
- Artifact paths are relative to the step's `workingDir`. Use absolute paths
  (`/data/artifacts/**`) to avoid ambiguity.
- Use `condition: always` so artifacts are saved even if the test step fails.
- Glob patterns use [doublestar](https://github.com/bmatcuk/doublestar) syntax.

## Pattern 6: Template Usage

**Use when**: Reusing a predefined TestWorkflowTemplate with configuration
parameters. Templates encapsulate common patterns (official/k6, official/cypress).

```yaml
steps:
- name: Run k6 from template
  template:
    name: official/k6
    config:
      version: "0.49.0"
      duration: "30s"
```

The template's config parameters depend on the template definition.
Check the template's `spec.config` for available parameters. Templates are
inlined before execution — `use` at top-level shares defaults across the
entire workflow; `template` at step-level is fully isolated.

## Pattern 7: Execute Composition

**Use when**: Running multiple existing workflows or tests as a suite.
The `execute` step orchestrates other Testkube resources by name.

```yaml
steps:
- execute:
    parallelism: 2
    workflows:
    - name: playwright-smoke
    - name: cypress-smoke
```

Set `parallelism` to control how many execute concurrently. The workflows
referenced must already exist in the same namespace.

## Pattern 8: Parallel Execution

**Use when**: Running the same test with different parameters (matrix)
or splitting work across shards.

### Simple parallel (count)

Run N identical copies of a step. Use when you don't need per-copy variation.

```yaml
steps:
- name: Parallel k6
  parallel:
    count: 3
    run:
      image: grafana/k6:0.49.0
      shell: k6 run test.js --duration 30s
```

### Matrix parallel (production)

Run the same step with different configurations — browsers, versions, datasets.
This is the production pattern, commonly used with `transfer` and `fetch`.

```yaml
steps:
- name: Run tests across browsers
  parallel:
    # One worker per matrix value
    matrix:
      browser: ['chrome', 'firefox']
    # transfer: share files to workers before they start.
    # Without this, each worker starts with an empty filesystem.
    transfer:
    - from: /data/repo
    # fetch: collect files from workers after they complete.
    # Routes each worker's output to a browser-specific directory.
    fetch:
    - from: /data/artifacts
      to: /data/artifacts/{{ matrix.browser }}
    # Per-worker resources — override global defaults
    container:
      resources:
        requests:
          cpu: 1500m
          memory: 2Gi
    run:
      args:
      - '--browser'
      - '{{ matrix.browser }}'
  # Parent-level artifacts include everything fetched from workers
  artifacts:
    paths:
    - '**/*'
```

**transfer** copies files from the current step's container to all workers before
they start — essential for sharing a git checkout or pre-built assets. **fetch**
copies files from workers back to the parent after they complete — use it to
collect per-worker results without losing them.

Matrix values are accessible via `{{ matrix.<name> }}` in descriptions, command
args, env vars, and artifact paths. For numeric iteration, use `count` and
access `{{ index }}` and `{{ count }}` in each worker.

For a complete working example, see `examples/parallel-matrix.yaml`.

Add `failFast: true` to cancel remaining workers on first failure:

```yaml
parallel:
  failFast: true
  matrix:
    browser: ['chrome', 'firefox']
```

Control max concurrent workers with `parallelism` (defaults to `count`):

```yaml
parallel:
  count: 10
  parallelism: 3  # only 3 workers run at a time
```

## Pattern 9: Services (Sidecars)

**Use when**: Your test needs a companion service — a database, Selenium
browser, Docker daemon, or mock API. Services run in separate containers
alongside your workflow steps.

```yaml
spec:
  services:
    postgres:
      image: postgres:16-alpine
      timeout: 120s
      logs: always
      env:
      - name: POSTGRES_USER
        value: test
      - name: POSTGRES_PASSWORD
        value: test
      - name: POSTGRES_DB
        value: testdb
      readinessProbe:
        tcpSocket:
          port: 5432
        periodSeconds: 1
  steps:
  - name: Run tests with DB
    run:
      image: node:22
      shell: |
        echo "DB host: {{ services.postgres.0.ip }}"
        npm test
      env:
      - name: DATABASE_URL
        value: postgres://test:test@{{ services.postgres.0.ip }}:5432/testdb
```

Reference a service by name and index: `{{ services.postgres.0.ip }}` gives
the IP of the first postgres service instance. Use `readinessProbe` to ensure
the service is ready before steps execute.

## Pattern 10: Config + Expressions (self-contained)

**Use when**: You want the workflow to accept parameters — version numbers,
URLs, counts — that can be overridden at runtime via CLI or the dashboard.

```yaml
apiVersion: testworkflows.testkube.io/v1
kind: TestWorkflow
metadata:
  name: config-expressions
spec:
  config:
    targetUrl:
      type: string
      default: "https://test.k6.io"
    VUS:
      type: integer
      default: 5
  content:
    files:
    - path: /data/test.js
      content: |
        import http from 'k6/http';
        export default function() { http.get(__ENV.TARGET_URL); }
  container:
    image: grafana/k6:0.49.0
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
    workingDir: /data
  steps:
  - name: Run parameterized test
    shell: k6 run -e TARGET_URL={{ config.targetUrl }} --vus {{ config.VUS }} test.js
    artifacts:
      paths:
      - '**/*'
```

Override config at runtime: `testkube run testworkflow config-expressions --config VUS=10 --config targetUrl=https://example.com`

Available expression helpers: `{{ config.param }}`, `{{ services.name.0.ip }}`,
`{{ shellquote(env.VAR) }}`, `{{ env.VAR }}`.

### Secret references via expressions

Use `secret()` to reference Kubernetes Secrets in env vars without exposing values:

```yaml
env:
- name: API_TOKEN
  value: '{{ secret("my-secret", "token") }}'
```

### Math in expressions

Arithmetic works directly in `{{ }}` blocks:

```yaml
shell: k6 run --vus {{ config.workers * 5 }} test.js
```

Expressions also support comparison (`config.VUS > 10 ? 5 : 2`), string
functions (`split()`, `join()`), and JSON parsing. Full reference:
https://docs.testkube.io/articles/test-workflows-expressions

### Credential references

Use `credential()` for Testkube-managed credentials (managed in Dashboard):

```yaml
env:
- name: API_KEY
  value: '{{ credential("my-api-key") }}'
```

### Global environment variables

Standard `env` entries only reach the main container. Add `global: true` to
propagate to services and parallel workers:

```yaml
container:
  env:
  - name: TARGET_URL
    value: "https://staging.example.com"
    global: true
```

## Pattern 11: Cron Trigger (self-contained)

**Use when**: The workflow should run on a schedule — hourly, daily, weekly.
Uses standard Cron syntax.

```yaml
apiVersion: testworkflows.testkube.io/v1
kind: TestWorkflow
metadata:
  name: cron-trigger
spec:
  events:
  - cronjob:
      cron: "0 * * * *"
      # timezone is optional — defaults to UTC if not set
      timezone: "Europe/Warsaw"
  container:
    image: alpine:latest
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
  steps:
  - name: Scheduled task
    shell: echo "Running at $(date)"
```

Common cron expressions:

| Expression | Meaning |
|-----------|--------|
| `*/30 * * * *` | Every 30 minutes |
| `0 * * * *` | Every hour (at minute 0) |
| `0 */4 * * *` | Every 4 hours |
| `0 0 * * *` | Daily at midnight |
| `0 9 * * 1-5` | Weekdays at 9am |

Standard 5-field cron: minute hour day-of-month month day-of-week.

## Pattern 12: Setup and After Hooks (self-contained)

**Use when**: You need steps that run before the main workflow (setup)
or after it regardless of success/failure (after, for cleanup).

```yaml
apiVersion: testworkflows.testkube.io/v1
kind: TestWorkflow
metadata:
  name: setup-after-hooks
spec:
  container:
    image: alpine:latest
    resources:
      requests:
        cpu: 128m
        memory: 128Mi
  setup:
  - name: Prepare environment
    shell: echo "Setting up..." && mkdir -p /data/work
  steps:
  - name: Main task
    shell: echo "Doing work..." > /data/work/output.txt
  after:
  - name: Cleanup
    condition: always
    shell: echo "Cleaning up..." && rm -rf /data/work
```

`setup` steps run before `steps`. `after` steps run after everything, even if
previous steps failed. Use `condition: always` in after steps to ensure cleanup
executes regardless of failure. Both `setup` and `after` follow the same step
schema as `steps`.

## Pattern 13: Step Data Sharing

**Use when**: Passing values or files from one step to a later step within
the same pod. Two mechanisms: output values (strings) and results directories
(files).

### Output values

Write to `/testkube/outputs/<key>` in one step, read in another with
`{{ step.<id>.outputs.<key> }}`. Give steps an explicit `id` for readability.

```yaml
steps:
- name: Setup
  id: setup
  shell: |
    echo "my-generated-token" > /testkube/outputs/token
- name: Test
  id: test
  shell: |
    echo "Using token: {{ step.setup.outputs.token }}"
```

### Results directories

Each step has a results directory at `{{ step.results }}`. Files written there
are accessible to later steps at `{{ step.<id>.results }}/`. Use this for
binaries, config files, or test fixtures.

```yaml
steps:
- name: Build
  id: build
  shell: |
    echo 'echo "running"' > {{ step.results }}/app
    chmod +x {{ step.results }}/app
- name: Run
  id: run
  shell: |
    {{ step.build.results }}/app
```

Output values are strings — write JSON if you need structured data. Both
mechanisms work within a single pod. For cross-pod sharing (parallel workers),
use `transfer`/`fetch` (see Pattern 8).

## Pattern 14: Retry and Negative Testing

**Use when**: Handling flaky steps or testing error conditions.

### Retry with expressions

Use `retry` with an `until` expression for flaky operations:

```yaml
steps:
- name: Wait for service
  retry:
    count: 10
    until: self.passed
  shell: curl -f https://my-service/health
```

### Negative testing

Use `negative: true` to invert pass/fail — the step succeeds when the command
fails. Useful for testing error handling:

```yaml
steps:
- name: Should return 404
  negative: true
  shell: curl -f https://api.example.com/nonexistent
```
