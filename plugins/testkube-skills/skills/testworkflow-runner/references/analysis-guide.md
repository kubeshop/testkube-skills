# Execution Analysis Guide

How to interpret TestWorkflow execution results and diagnose failures.

## Check Execution Status

Get the execution details:

```bash
testkube get testworkflowexecution <execution-id>
```

The execution goes through states: `queued` → `running` → `passed` / `failed` /
`aborted`. If the status is still `running`, the workflow hasn't finished — wait
and re-check. If `queued`, the cluster hasn't scheduled it yet (resource
shortage, image pull in progress).

## Read the Logs

Logs are the primary debugging tool. Each step's output is captured separately:

```bash
testkube get testworkflowexecution <execution-id> --logs-only
```

Log output is attributed per step. Look for the last lines before the failure —
the error message that caused the exit is usually there. Shell steps
auto-prepend `set -e`, so the first failing command in a shell step stops
execution immediately.

## Common Failure Patterns

| Symptom | Likely Cause | What to Try |
|---------|-------------|------------|
| Non-zero exit code | Test command failed | Read the test output in logs — assertion failures, missing files, wrong paths |
| `OOMKilled` | Container exceeded memory limit | Increase `resources.limits.memory` or `resources.requests.memory` in `spec.container` |
| `ImagePullBackOff` | Image not found or private registry | Verify image name and tag. For private registries, add `spec.pod.imagePullSecrets` |
| `ErrImagePull` | Image name wrong or registry unreachable | Check for typos in the image name. Verify the registry URL is reachable |
| `DeadlineExceeded` | Step or workflow timed out | Increase `timeout` on the step, or increase `spec.job.activeDeadlineSeconds` |
| `CrashLoopBackOff` | Container crashes on startup | Check the `command`/`args` are correct. Verify the image's entrypoint works |
| Step stuck in `running` | Infinite loop or waiting for input | Add `timeout` to the step. Check if the command needs stdin |

For `OOMKilled` and timeout errors, check the step that failed — each step has
its own resource and timeout configuration. A workflow-level timeout only
applies if no step-level timeout is set.

## JUnit Reports

If your test outputs JUnit XML and you collected it as an artifact, Testkube
automatically parses it. Check the Dashboard Reports tab for per-test-case
results — passed, failed, skipped — with error messages for failures.
No CLI command is needed; the parsing happens server-side.

To retrieve the raw XML artifact:

```bash
testkube download artifacts <execution-id> --mask '.*\.xml$'
```

## Check Artifacts

List all artifacts for an execution:

```bash
testkube get testworkflowexecution <execution-id>
```

Download all artifacts to a local directory:

```bash
testkube download artifacts <execution-id> --download-dir ./results
```

Filter by filename pattern:

```bash
testkube download artifacts <execution-id> --download-dir ./results --mask '.*\.xml$'
```

Artifacts may contain screenshots (Playwright, Cypress), HTML reports, log
files, or summary JSON — check them for context beyond what the console logs
show.

## Step-Level Debugging

Each step in a workflow has its own status. If a multi-step workflow fails:

1. Identify which step failed — the execution output shows per-step status.
2. Focus on that step's logs, not the whole workflow output.
3. Check if the failed step has `optional: true` — optional failures don't
   fail the workflow, but the step might still have useful error output.
4. Nested steps also have individual status — drill down into sub-steps.

If a step has `condition: always` and fails, it still runs after the failure
but its output is separate from the step that caused the failure.
