---
name: testkube
description: >
  Orientation and routing for Testkube — the open testing platform that runs tests as Kubernetes-native TestWorkflows.
  Use when the user mentions Testkube, TestWorkflow, TestWorkflowTemplate, TestTrigger, a Testkube webhook, the
  `testkube` / `tk` / `kubectl-testkube` CLI, or a Testkube Control Plane or agent, and no more specific Testkube skill
  already covers the task. Explains the platform model, indexes the official docs at https://docs.testkube.io, and
  routes to the specialist skills (installing-testkube-cli, installing-testkube-oss-agent, test-discovery,
  testworkflow-author, testworkflow-runner). Always prefer fetching current docs over pre-trained knowledge. This skill
  orients and routes — it does NOT install anything, author YAML, or run executions itself.
metadata:
  initiative: test-authoring
---

# testkube

[Testkube](https://testkube.io) is an open testing platform that runs tests inside Kubernetes. A test is declared as a
`TestWorkflow` — a Kubernetes custom resource describing which container image to run, which repository to check out,
and which commands to execute. Testkube turns that resource into a Kubernetes Job and reports back status, logs,
artifacts, and JUnit results. Any framework that runs in a container runs in Testkube: Playwright, Cypress, k6, JMeter,
Postman, Selenium, Go, Maven, Gradle, Robot Framework, and anything else with a CLI.

Testkube runs in two shapes. **Open-source standalone** is a single agent in one cluster, driven entirely from the CLI.
**Control Plane** (Testkube Cloud or on-prem) adds a dashboard, multi-environment management, and multiple connected
agents with distinct capabilities. Which shape is in play changes what commands and features are available — see
[Deployment topologies](#deployment-topologies) before answering questions about capabilities.

**This skill orients and routes.** It teaches the platform model, indexes the docs, and points at the skill that does
the actual work. It does not install, author, or execute anything itself.

## Retrieval sources

Testkube ships faster than any model's training data. Fetch, do not recall.

| Need                                     | Source                                                                          |
| ---------------------------------------- | ------------------------------------------------------------------------------- |
| Anything conceptual, current behavior    | https://docs.testkube.io — fetch the page                                        |
| CLI verbs, flags, resource names         | `testkube <verb> <resource> --help` — run it                                     |
| TestWorkflow field-level schema          | `../testworkflow-author/assets/workflow-schema.yaml`                             |
| TestWorkflowTemplate schema              | `../testworkflow-author/assets/template-schema.yaml`                             |
| Live CRD shape in a cluster              | `kubectl explain testworkflow.spec --recursive`                                  |
| Deep TestWorkflow concepts               | `../testworkflow-author/references/docs-concepts.md`                             |
| Worked YAML (22 frameworks)              | `../testworkflow-author/examples/` — indexed in `../testworkflow-author/references/examples-catalog.md` |
| REST API                                 | https://docs.testkube.io/openapi/overview                                        |
| CRD reference                            | https://docs.testkube.io/articles/crds                                           |
| What changed recently                    | https://docs.testkube.io/changelog                                               |

When the docs and any bundled reference file disagree, **the docs win** — reference files are snapshots.

## Rules

These are mandatory. Violating any rule produces answers that look authoritative and are wrong.

1. **MUST hand off to a specialist skill when one matches.** This skill orients; it does not execute. See
   [Skill index](#skill-index).
2. **MUST fetch the doc page before answering a factual question** about Testkube behavior, CLI flags, or CRD fields.
   **MUST NOT** answer from memory — pre-trained knowledge of Testkube is stale and skews toward the deprecated
   `Test` / `TestSuite` API.
3. **MUST NOT invent CLI flags, CRD fields, or `apiVersion` values.** Verify against `--help`, the bundled schemas, or
   the docs.
4. **MUST NOT author or edit TestWorkflow YAML here** — that is `testworkflow-author`.
5. **MUST NOT run, watch, or diagnose executions here** — that is `testworkflow-runner`.
6. **MUST say so plainly when no skill covers the task**, then route to the doc URL and the relevant
   `testkube ... --help`. See [Not covered by a skill](#not-covered-by-a-skill).

## Quick decision trees

### "I want to run my tests with Testkube"

```
Is the `testkube` command available?
├── no  ──► installing-testkube-cli
└── yes
    │
    Is there a Testkube environment to run against?
    ├── no, and I want a local one  ──► installing-testkube-oss-agent
    ├── no, and I want Cloud/on-prem ──► docs: /articles/install/overview
    └── yes
        │
        Do I know what tests exist and what runs them?
        ├── no  ──► test-discovery   (emits test-manifest.json)
        └── yes
            │
            ──► testworkflow-author  (writes + validates workflow.yaml)
            │
            ──► testworkflow-runner  (runs it, diagnoses failures)
```

### "I need a Testkube environment"

```
Local cluster, open source, CLI-driven, no dashboard
  └──► installing-testkube-oss-agent

Testkube Cloud or on-prem Control Plane (dashboard, multi-env, licensed runners)
  └──► docs: /articles/install/overview, /articles/install/multi-agent

Not sure which one I need
  └──► docs: /articles/install/feature-comparison
```

### "My workflow failed"

```
──► testworkflow-runner   reads logs, identifies root cause, reports exit code
    │
    ├── root cause is a workflow config problem (wrong image, missing step, bad command)
    │     └──► hand the finding to testworkflow-author to fix the YAML, then re-run
    │
    ├── root cause is a real test assertion failure
    │     └──► the workflow is fine; the tests found a bug
    │
    └── root cause is environment (agent down, no license, image pull)
          └──► installing-testkube-oss-agent (local) or docs: /articles/install/overview
```

### "I want tests to run automatically"

```
On a schedule                       ──► cron in the workflow spec: testworkflow-author
                                        (see examples/cron-trigger.yaml)
On a Kubernetes event (deploy, etc) ──► TestTrigger — docs: /articles/test-triggers  [no skill]
From a CI/CD pipeline               ──► docs: /articles/cicd-overview, /articles/github-actions  [no skill]
From another workflow               ──► `execute` step: testworkflow-author
                                        (see examples/suite-execute.yaml)
Overview of every trigger mechanism ──► docs: /articles/triggering-overview
```

### "I want to be notified when a test finishes"

```
HTTP callback to an external system ──► Webhooks — docs: /articles/webhooks           [no skill]
Reusable webhook definition         ──► Webhook templates — docs: /articles/webhooks  [no skill]
CDEvents / Kubernetes events        ──► docs: /articles/cd-events                     [no skill]
```

### "I want to share setup across workflows"

```
──► TestWorkflowTemplate — docs: /articles/test-workflow-templates, /articles/templates
    │
    ├── writing or consuming the template YAML  ──► testworkflow-author
    │                                               (see examples/jmeter-template.yaml,
    │                                                examples/step-level-use.yaml)
    └── CRUD on templates in a live environment ──► `testkube create/get/delete testworkflowtemplate --help`
```

## Skill index

| I need to...                                                              | Skill                           | Does NOT                                            |
| ------------------------------------------------------------------------- | ------------------------------- | --------------------------------------------------- |
| Install, upgrade, or verify the `testkube` CLI                            | `installing-testkube-cli`       | Deploy an agent or cluster                          |
| Get a local OSS Testkube environment running                              | `installing-testkube-oss-agent` | Set up a Control Plane; install the CLI itself      |
| Find out what tests a cloned repo has and what runs them                  | `test-discovery`                | Execute tests, install deps, or write YAML          |
| Write or fix TestWorkflow / TestWorkflowTemplate YAML                     | `testworkflow-author`           | Run the workflow                                    |
| Run a workflow, read logs, diagnose a failure                             | `testworkflow-runner`           | Edit workflow YAML                                  |
| Anything else (webhooks, triggers, integrations, resource CRUD, RBAC)     | *none ships in this plugin*     | — see [Not covered by a skill](#not-covered-by-a-skill) |

The skills chain: `test-discovery` → `testworkflow-author` → `testworkflow-runner`, with the two `installing-*` skills
as prerequisites. `installing-testkube-oss-agent` treats `installing-testkube-cli` as a **REQUIRED SUB-SKILL**.

## Concept glossary

**TestWorkflow** — the core resource (`apiVersion: testworkflows.testkube.io/v1`, `kind: TestWorkflow`). Declares
content (git checkout or inline files), container image, and an ordered list of steps.
See https://docs.testkube.io/articles/test-workflows

**TestWorkflowTemplate** — a reusable building block with the same schema shape (`kind: TestWorkflowTemplate`).
Workflows pull it in with `use` (top-level or step-level) or `template` (isolated). Templates cannot include other
templates. See https://docs.testkube.io/articles/test-workflow-templates

**TestWorkflowExecution** — one run of a workflow, with its own id, status, step results, logs, and artifacts. This is
what `testkube run` produces and what `testkube get testworkflowexecution` reads.

**Execution model** — Testkube creates a Kubernetes Job, which creates a Pod. Steps run as **sequential init
containers**; the last step runs as the main container. All steps share the `/data` volume; git content lands in
`/data/repo`. Job, Pod, and ConfigMaps are cleaned up afterward.
See https://docs.testkube.io/articles/test-workflows-high-level-architecture

**Control Plane** — the central component (Testkube Cloud or on-prem) providing the dashboard, organizations,
environments, and coordination of connected agents. Not present in OSS standalone.

**Agent** — a Testkube deployment in a cluster that connects to a Control Plane. Since 2.7.0 an agent carries any
combination of four capabilities: **runner** (executes workflows — requires a license), **listener** (watches
Kubernetes events for TestTriggers), **gitops** (syncs resources from a namespace into the Control Plane), and
**webhook** (emits webhooks, CDEvents, Kubernetes events).
See https://docs.testkube.io/articles/agents-overview

**Standalone Agent** — the open-source single-cluster deployment. No Control Plane, no dashboard; driven from the CLI.
See https://docs.testkube.io/articles/install/standalone-agent

**Organization / environment** — Control Plane scoping. An organization holds environments; each environment is a
logical boundary for workflows, executions, and connected agents.

**TestTrigger** — a Kubernetes-event-driven rule ("when this Deployment rolls, run that workflow"). Defined by a
YAML/JSON manifest, served by a listener agent. See https://docs.testkube.io/articles/test-triggers

**Webhook / WebhookTemplate** — outbound HTTP notification on execution events (start-test, end-testworkflow, and
friends), with a custom payload; templates make the definition reusable.
See https://docs.testkube.io/articles/webhooks

**Artifacts** — files collected from steps via `artifacts.paths` glob patterns, stored in MinIO or S3-compatible
storage. Testkube automatically scans `.xml` artifacts for JUnit reports.
See https://docs.testkube.io/articles/test-workflows-artifacts and
https://docs.testkube.io/articles/test-workflows-reports

**Expressions** — the `{{ }}` templating language available in most string fields: arithmetic, comparisons, string and
JSON functions, `secret()`, `shellquote()`, plus built-ins like `execution.id`, `workflow.name`, `config.*`, `matrix.*`,
`failed`, `passed`. See https://docs.testkube.io/articles/test-workflows-expressions

**`Test` / `TestSuite` (legacy)** — the pre-TestWorkflow API. **Deprecated.** New work uses TestWorkflows.
See https://docs.testkube.io/articles/legacy-deprecation

## Deployment topologies

Getting this wrong is the most common source of confidently incorrect Testkube answers. Establish which topology is in
play before describing capabilities.

| | **OSS standalone agent** | **Control Plane (Cloud / on-prem)** |
| --- | --- | --- |
| Dashboard | none — CLI only | yes |
| Scope | one cluster, one namespace | many environments, many connected agents |
| Auth | local kubeconfig / API URI | `testkube login`, org + environment context |
| Runner agents | n/a | yes (licensed) |
| Listener / GitOps / webhook agents | n/a | yes |
| License | not required | required for licensed capabilities |
| Set up with | `installing-testkube-oss-agent` | https://docs.testkube.io/articles/install/overview |

Full matrix: https://docs.testkube.io/articles/install/feature-comparison

## Docs index

All URLs below are under `https://docs.testkube.io`.

**Start here**

| Page | URL |
| --- | --- |
| Documentation home | https://docs.testkube.io/ |
| Open source overview | https://docs.testkube.io/articles/open-source |
| Quickstart (OSS) | https://docs.testkube.io/articles/getting-started-with-open-source |
| Hands-on tutorial | https://docs.testkube.io/articles/tutorial/quickstart/overview |
| Testkube for AI agents | https://docs.testkube.io/articles/ai-agents |

**Install**

| Page | URL |
| --- | --- |
| Install overview | https://docs.testkube.io/articles/install/overview |
| Standalone agent (OSS) | https://docs.testkube.io/articles/install/standalone-agent |
| Multi-agent install | https://docs.testkube.io/articles/install/multi-agent |
| Install with Helm | https://docs.testkube.io/articles/install/install-with-helm |
| Advanced install | https://docs.testkube.io/articles/install/advanced-install |
| OSS vs Control Plane | https://docs.testkube.io/articles/install/feature-comparison |
| Testkube OSS | https://docs.testkube.io/articles/testkube-oss |
| Dependencies | https://docs.testkube.io/articles/testkube-dependencies |

**Concepts**

| Page | URL |
| --- | --- |
| Testing pipeline | https://docs.testkube.io/articles/testing-pipeline |
| Architecture | https://docs.testkube.io/articles/architecture |
| Agents overview | https://docs.testkube.io/articles/agents-overview |
| Agent CLI commands | https://docs.testkube.io/articles/multi-agent-cli |
| Using Testkube | https://docs.testkube.io/articles/using-testkube |

**TestWorkflows**

| Page | URL |
| --- | --- |
| Overview | https://docs.testkube.io/articles/test-workflows |
| Creating | https://docs.testkube.io/articles/test-workflows-creating |
| Running | https://docs.testkube.io/articles/test-workflows-running |
| Execution architecture | https://docs.testkube.io/articles/test-workflows-high-level-architecture |
| Templates | https://docs.testkube.io/articles/test-workflow-templates |
| Official templates | https://docs.testkube.io/articles/templates |
| Basic examples | https://docs.testkube.io/articles/test-workflows-examples-basics |
| Content (git, files) | https://docs.testkube.io/articles/test-workflows-content |
| Artifacts | https://docs.testkube.io/articles/test-workflows-artifacts |
| Reports (JUnit) | https://docs.testkube.io/articles/test-workflows-reports |
| Services | https://docs.testkube.io/articles/test-workflows-services |
| Parallelization | https://docs.testkube.io/articles/test-workflows-parallel |
| Matrix & sharding | https://docs.testkube.io/articles/test-workflows-matrix-and-sharding |
| Expressions | https://docs.testkube.io/articles/test-workflows-expressions |
| Step data sharing | https://docs.testkube.io/articles/test-workflows-step-sharing |
| Suites (`execute`) | https://docs.testkube.io/articles/test-workflows-test-suites |

**Automation & integrations**

| Page | URL |
| --- | --- |
| Triggering overview | https://docs.testkube.io/articles/triggering-overview |
| Test triggers | https://docs.testkube.io/articles/test-triggers |
| Webhooks | https://docs.testkube.io/articles/webhooks |
| CDEvents | https://docs.testkube.io/articles/cd-events |
| GitOps | https://docs.testkube.io/articles/gitops-overview |
| CI/CD overview | https://docs.testkube.io/articles/cicd-overview |
| GitHub Actions | https://docs.testkube.io/articles/github-actions |
| Integrations | https://docs.testkube.io/articles/integrations |
| MCP server (preview) | https://docs.testkube.io/articles/mcp-overview |

**Reference**

| Page | URL |
| --- | --- |
| CLI reference | https://docs.testkube.io/cli/testkube |
| OpenAPI / REST | https://docs.testkube.io/openapi/overview |
| CRDs | https://docs.testkube.io/articles/crds |
| Licensing | https://docs.testkube.io/articles/licensing |
| Telemetry | https://docs.testkube.io/articles/telemetry |
| Legacy deprecations | https://docs.testkube.io/articles/legacy-deprecation |
| Logging | https://docs.testkube.io/articles/logging |
| Examples & guides | https://docs.testkube.io/articles/examples/overview |
| Changelog | https://docs.testkube.io/changelog |

## CLI orientation

Learn the shape of the CLI, then discover the details with `--help`. Do not recall flags.

The same binary is installed under three names — `testkube`, `tk`, and `kubectl-testkube` (invoked as
`kubectl testkube`). Resolve it defensively before use:

```bash
TK_CMD="$(command -v testkube || command -v tk || command -v kubectl-testkube)"
[ -n "$TK_CMD" ] || echo "Testkube CLI not found; use installing-testkube-cli"
```

Commands follow `testkube <verb> <resource> [name] [flags]`:

| Verb | Purpose |
| --- | --- |
| `create` | Create a resource, usually from `-f <file>`; `--update` upserts |
| `get` | List resources, or show one by name |
| `update` | Update an existing resource |
| `delete` | Delete a resource |
| `run` | Start a workflow execution (`-f` streams and blocks until terminal) |
| `watch` | Follow a running execution |
| `cancel` | Cancel executions |
| `download` | Fetch artifacts from an execution |

Resource names and their aliases:

| Resource | Aliases |
| --- | --- |
| `testworkflow` | `testworkflows`, `tw` |
| `testworkflowexecution` | `testworkflowexecutions`, `twe`, `twexecution` |
| `testworkflowtemplate` | `testworkflowtemplates`, `twt` |
| `testtrigger` | `testtriggers`, `tt` |
| `workflowtrigger` (v2) | `workflowtriggers`, `wt` |
| `webhook` | `webhooks`, `wh` |
| `webhooktemplate` | `webhooktemplates`, `wht` |

Context and status:

```bash
testkube version                 # CLI + server version, current context and namespace
testkube status                  # feature / resource status
testkube login                   # authenticate against a Control Plane
testkube set context --help      # switch org / environment / namespace
testkube dashboard               # open the dashboard (Control Plane only)
testkube --help                  # full verb list, including agent, mcp, debug, diagnostics
```

Full reference: https://docs.testkube.io/cli/testkube

## Not covered by a skill

**No skill in this plugin covers the tasks below.** Say so, then use the doc page and the `--help` output.

| Task | Docs | CLI |
| --- | --- | --- |
| Webhooks | https://docs.testkube.io/articles/webhooks | `testkube create webhook --help` |
| Webhook templates | https://docs.testkube.io/articles/webhooks | `testkube create webhooktemplate --help` |
| Test triggers | https://docs.testkube.io/articles/test-triggers | `testkube create testtrigger --help` |
| Workflow triggers (v2) | https://docs.testkube.io/articles/triggering-overview | `testkube create workflowtrigger --help` |
| TestWorkflowTemplate CRUD | https://docs.testkube.io/articles/test-workflow-templates | `testkube create testworkflowtemplate --help` |
| GitOps sync | https://docs.testkube.io/articles/gitops-overview | `testkube agent --help` |
| CI/CD integration | https://docs.testkube.io/articles/cicd-overview | — |
| Control Plane install | https://docs.testkube.io/articles/install/overview | `testkube init --help` |
| Agents & runners | https://docs.testkube.io/articles/agents-overview | `testkube create runner --help` |
| MCP server (preview) | https://docs.testkube.io/articles/mcp-overview | `testkube mcp --help` |
| Licensing | https://docs.testkube.io/articles/licensing | — |

## Gotchas

- **Answering from memory** — pre-trained knowledge of Testkube is stale and biased toward the deprecated
  `Test` / `TestSuite` API. Fetch the doc page or run `--help` before stating a fact.
- **Recommending `kind: Test` or `testkube create test`** — that is the legacy API. New work uses `TestWorkflow`.
- **Assuming a dashboard exists** — the OSS standalone agent has none. `testkube dashboard` is a Control Plane feature.
- **Assuming runner / listener / gitops / webhook agents are available** — those are Control Plane capabilities, and
  runner agents require a license. They do not exist in OSS standalone.
- **Expecting sidecars in steps** — steps run as init containers, so operator-injected sidecars (Istio, Linkerd) are
  not reachable from them. Container merging exists partly to mitigate this.
- **Expecting a fresh filesystem per step** — steps in one pod share `/data`. Parallel workers do not: use
  `transfer` / `fetch`.
- **Guessing doc URLs** — `docs.testkube.io/...` and `testkube.io/docs/...` both resolve, but invented slugs 404.
  Use the [Docs index](#docs-index) or search from https://docs.testkube.io/.
- **Doing the specialist skill's job** — if the request is "write this workflow" or "run and debug this", stop routing
  and hand off. This skill produces orientation, not artifacts.
