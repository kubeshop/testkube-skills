# TestWorkflow Concepts

Key concepts that explain how Testkube works, beyond what the schema describes.
Each section covers one concept — read when you need to understand why something
works the way it does.

## Execution Model

When a TestWorkflow runs, the Testkube controller creates a Kubernetes Job,
which creates a Pod. Steps are executed as init containers sequentially within
that pod — step 1 runs first, then step 2, etc. The last step runs as the main
container. All resources (Job, Pod, ConfigMaps) are cleaned up after execution.

**See**: https://docs.testkube.io/articles/test-workflows-high-level-architecture

## Container Merging

By default, Testkube merges multiple simple steps into a single container to
reduce startup overhead. Merged steps share the same filesystem and process
space but sacrifice isolation. Use `spec.system.isolatedContainers: true` to
force each step into its own container. Merging is an optimization, not a
requirement — disable it if your steps conflict.

**See**: https://docs.testkube.io/articles/test-workflows-high-level-architecture

## Shared Filesystem & Step Nesting

All steps within a workflow share the `/data` volume. Git checkouts clone to
`/data/repo` by default, and inline files under `/data/` are accessible to
every step. When using `parallel.matrix`, use `transfer` to copy files from the
parent container to workers before they start, and `fetch` to collect per-worker
results back. Without `transfer`, parallel workers start with empty filesystems.

Nested steps (`steps:` inside a step) run sequentially within the parent step's
container — they share the same filesystem and process space. This is useful for
logical grouping (install → test → save artifacts) within a single tool image.
Top-level steps run in order but may be merged into different containers
depending on container merging behavior.

For parallel file sharing patterns, see `references/step-patterns.md` Pattern 8
and `examples/parallel-matrix.yaml`.

**See**: https://docs.testkube.io/articles/test-workflows-high-level-architecture

## Init Containers and Sidecars

Because steps run as init containers, sidecar containers injected by operators
(Istio, Linkerd) into the main `containers` section are not available to steps.
This is a Kubernetes limitation — init containers complete before sidecars
start. Container merging exists partly to work around this: merging steps into
fewer containers means fewer init containers. Newer Kubernetes versions with
native sidecar containers solve this at the platform level.

**See**: https://docs.testkube.io/articles/test-workflows-high-level-architecture

## Template Basics

TestWorkflowTemplates are reusable building blocks. They follow the same schema
as workflows (`kind: TestWorkflowTemplate`) but cannot include other templates.
Templates define configurable parameters that workflows override when using
them. Use templates to standardize common patterns — tool setup, resource
constraints, log collection — across your organization.

**See**: https://docs.testkube.io/articles/test-workflow-templates

## Template Scoping

When a workflow uses a template, the scope determines how its defaults
propagate. `use` at the top level shares the template's defaults across all
steps. `use` at the step level scopes defaults to that step only. `template`
at the step level is fully isolated — no defaults leak outside. Choose the
scope based on whether you want the template's settings to affect other steps.

**See**: https://docs.testkube.io/articles/test-workflows-examples-templates

## Artifact Collection

Artifacts are files collected from workflow steps after execution. Specify
`artifacts.paths` with glob patterns (doublestar syntax). Paths are relative
to the step's `workingDir` — use absolute paths for clarity. Artifacts are
stored in MinIO (or S3-compatible storage) and retrieved via CLI, API, or
Dashboard. Testkube automatically scans `.xml` artifacts for JUnit reports.

**See**: https://docs.testkube.io/articles/test-workflows-artifacts

## Runner Agent Targeting

By default, workflows execute on the Standalone Agent connected to your
environment. To run on a specific Runner Agent, use `--target name=<agent>`
with `testkube run testworkflow`. For multi-agent execution, use
`--target-replicate` to run the same workflow across multiple runners.

**See**: https://docs.testkube.io/articles/test-workflows-running

## JUnit Report Extraction

Testkube automatically scans all `.xml` artifacts for valid JUnit reports.
Parsed reports appear in the Dashboard under the Overview tab (summary) and
Reports tab (detailed, searchable, filterable by status). No configuration
needed — just collect JUnit XML files as artifacts and Testkube handles the
rest.

**See**: https://docs.testkube.io/articles/test-workflows-reports

## Step Data Sharing

Steps in the same pod can pass data to each other through two mechanisms.
**Output values** (`/testkube/outputs/<key>`) are simple strings written by one
step and read by another with `{{ step.<id>.outputs.<key> }}`. Give steps an
explicit `id` to reference them by name. **Results directories**
(`{{ step.results }}`) allow passing files — write to the current step's
results dir, read from a previous step's at `{{ step.<id>.results }}/`.
Both mechanisms work within a single pod; for cross-pod sharing between
parallel workers, use `transfer`/`fetch` (see Pattern 8).

**See**: https://docs.testkube.io/articles/test-workflows-step-sharing

## Trigger Overview

Workflows can be triggered in multiple ways: manually from the Dashboard, from
a CI/CD pipeline, on a cron schedule, in response to Kubernetes events
(TestTrigger resources), by creating an Execution CRD, via the CLI
(`testkube run testworkflow`), via the REST API, or from another workflow
using the `execute` step type.

**See**: https://docs.testkube.io/articles/triggering-overview

## Expressions

TestWorkflows have a built-in expressions language for dynamic values at
runtime. Use `{{ }}` to embed expressions in most string fields — image tags,
shell commands, environment variables, conditions. Expressions support
arithmetic (`{{ config.workers * 5 }}`), comparison (`config.VUS > 10`),
string manipulation (`split()`, `join()`), JSON parsing (`json()`,
`tojson()`), and 30+ built-in functions including `secret()` for Kubernetes
Secret references, `shellquote()` for safe shell arguments, and `file()` /
`glob()` for filesystem queries.

Built-in variables include `execution.id`, `execution.name`, `workflow.name`,
`namespace`, `organization.id`, `environment.id`, `labels.*`, `failed`,
`passed`, `services.*.ip`, `step.results`, `matrix.*`, `shard.*`, `index`,
and `count`.

**See**: https://docs.testkube.io/articles/test-workflows-expressions
