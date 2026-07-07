---
name: testworkflow-runner
description: >
  Run, monitor, and diagnose Testkube TestWorkflow executions. Use when a TestWorkflow has been authored and needs to be
  executed, or when a previous execution failed and needs diagnosis. Reports execution results and root causes — does
  NOT edit workflow YAML.
metadata:
  initiative: test-authoring
---

# testworkflow-runner

Run a TestWorkflow, read execution logs, and diagnose failures. This skill handles the execution lifecycle AFTER the
workflow YAML has been written and validated by `testworkflow-author`.

This skill does NOT edit workflow YAML. If the diagnosis indicates a workflow configuration problem (wrong image,
missing step, incorrect command), report it in the deliverable — the parent agent decides whether to re-invoke
`testworkflow-author` with the fix.

## The Core Loop

1. **Review context** — check for context from previous agents (workflow file path, image chosen, install/run commands,
   known issues)
2. **Create and run the workflow** — create the workflow and start an execution. Use a blocking run so the command
   returns only when the execution completes:
   ```bash
   testkube create testworkflow -f workflow.yaml
   testkube run testworkflow <name> -f
   ```
   The default file path is `workflow.yaml`; pass the actual path if the workflow was written to a different location.
   The `-f` flag streams output and blocks until the execution reaches a terminal state (passed, failed, aborted).
3. **If failed, get logs** — use `--logs-only` to read just the execution logs. Filter by step or grep for error
   patterns:
   ```bash
   testkube get testworkflowexecution <execution-id> --logs-only
   ```
4. **Get execution details** — for full status, step results, and duration:
   ```bash
   testkube get testworkflowexecution <execution-id>
   ```
5. **Diagnose** — identify root cause using the Failure Patterns below.
6. **Report your diagnosis** — include workflow name, execution ID, status, exit code, and root cause with a
   recommendation.

## Rules

1. **MUST read the full execution logs before diagnosing.** Never guess the failure cause from the status alone. The
   error message in the logs is the source of truth.
2. **MUST report the EXACT error message from logs.** Copy the relevant error text verbatim — do not paraphrase or
   summarize it.
3. **MUST check the exit code.** Exit code 127 = command not found (missing dependency or wrong PATH). Exit code 1 =
   test assertion failure. Exit code 137 = OOMKilled.
4. **MUST NOT edit the workflow YAML.** Report what needs to change — the parent handles re-authoring.

## CLI Commands

| Command                                          | Purpose                                                              |
| ------------------------------------------------ | -------------------------------------------------------------------- |
| `testkube create testworkflow -f <file>`         | Create a workflow from a YAML file                                   |
| `testkube run testworkflow <name> -f`            | Run a workflow, stream output, block until completion                |
| `testkube get testworkflowexecution <id>`        | Get execution status, step results, duration, and artifact listing   |
| `testkube get testworkflowexecution <id> --logs-only` | Fetch execution logs (supports `--tail`, `--grep`, `--step`)    |
| `testkube download artifacts <id>`               | Download artifacts from an execution                                 |
| `testkube download artifacts <id> --mask '.*\.xml$'` | Download only JUnit XML artifacts                               |

Full CLI reference: `references/cli-reference.md`.

## Failure Patterns

| Symptom                                          | Exit Code | Root Cause                                                                                 | Recommendation                                                                                              |
| ------------------------------------------------ | --------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `command not found`                              | 127       | Binary not on PATH — missing `npm ci`/install step, or using bare command instead of `npx` | Add install step, use `npx <tool>`                                                                          |
| `Executable doesn't exist at /ms-playwright/...` | 1         | Playwright image version doesn't match installed package version                           | Match image tag to lock file version                                                                        |
| `Please update docker image as well`             | 1         | Playwright explicitly says image/package mismatch                                          | Use the version it suggests                                                                                 |
| `OOMKilled`                                      | 137       | Container exceeded memory limit                                                            | Increase `resources.limits.memory`                                                                          |
| `ImagePullBackOff` / `ErrImagePull`              | —         | Image name wrong or registry unreachable                                                   | Verify image exists on registry                                                                             |
| `DeadlineExceeded`                               | —         | Workflow or step timed out                                                                 | Increase `activeDeadlineSeconds`                                                                            |
| `CrashLoopBackOff`                               | —         | Container crashes on startup                                                               | Check `command`/`args` or image entrypoint                                                                  |
| Non-zero exit with test output                   | 1         | Test assertion failures (actual test bugs)                                                 | Tests ran correctly but found failures — this is expected behavior, report as test failure not config issue |

## Interpreting Exit Codes

- **Exit 0**: All tests passed
- **Exit 1**: Test failures (assertions) OR general error
- **Exit 127**: Command not found — the binary doesn't exist in PATH
- **Exit 137**: OOMKilled (SIGKILL from kernel)
- **Exit 143**: SIGTERM (timeout, graceful shutdown)

When exit code is 127, the fix is ALWAYS about dependency installation or PATH — never about the test code itself.

## Reference Index

| Reference                      | When to Load                                | Status    |
| ------------------------------ | ------------------------------------------- | --------- |
| `references/analysis-guide.md` | When needing detailed diagnostic procedures | Available |
| `references/cli-reference.md`  | When needing full CLI flags for run/get     | Available |
