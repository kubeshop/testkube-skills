# testworkflow-author — JSON mode contract tests

Guards the **optional** JSON input/output mode added to the `testworkflow-author`
skill, and — most importantly — that adding it did **not** change the skill's
default behavior.

## What is covered

| # | Check |
|---|-------|
| 1 | Every fixture and both skill schemas are valid JSON. |
| 2 | The example envelopes validate against `assets/json-mode-output.schema.json`, and the authoring request validates against `assets/json-mode-input.schema.json`. |
| 3 | The workflow YAML embedded in the success envelope is a real `TestWorkflow` (structural check; a full `testkube --dry-run` when the CLI is available). |
| 4 | **Regression:** `SKILL.md` still documents the default (free-form prose in → `testworkflow.yaml` out) behavior, still marks JSON mode opt-in, and still guarantees the YAML is identical across modes. |
| 5 | **Composition scenario:** a 4-suite `test-discovery` manifest is valid discovery output, the resulting envelope validates, and the orchestrator YAML composes all 4 suites via `execute` + config-gated `condition`s. |

## Fixtures

- `input.example.json` — a JSON authoring request (JSON **input** mode).
- `output.example.json` — a `success` JSON envelope with the generated workflow embedded (JSON **output** mode).
- `output.needs-input.example.json` — the `needs_input` envelope shape.
- `compose.discovery-input.json` — a `test-discovery` manifest with 4 suites (the upstream input to a composition request).
- `compose.output.example.json` — the `success` envelope whose workflow is a `release-suite` orchestrator running all 4 suites via `execute.workflows`, each gated by a boolean `spec.config` toggle (`runK6` defaults off). Demonstrates the `test-discovery → testworkflow-author` pipe.

## Run

```bash
tests/testworkflow-author-json-mode/run.sh
```

Dependencies: `bash` + `python3`. `jsonschema` (pip) and the `testkube` CLI are
used for stronger assertions when present and skipped gracefully otherwise. No
network access and no secrets.

## Why the default must not break

The default mode (natural-language requirements → a `testworkflow.yaml` file →
`--dry-run` validation → prose summary) is the correct, primary way to use the
skill. JSON mode is a thin wrapper for programmatic callers: the YAML it produces
is byte-for-byte the same. Check #4 fails the suite if the default contract is
ever removed from `SKILL.md`.
