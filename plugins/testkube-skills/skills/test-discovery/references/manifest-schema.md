# test-manifest schema (v1)

Full output contract. The skill emits one JSON document to stdout matching this schema. A machine-readable
JSON Schema equivalent is in `assets/manifest-schema.json`.

## Root

```json
{
  "schemaVersion": 1,
  "status": "success | needs_input | error | no_tests_found",
  "...": "shape depends on status"
}
```

`schemaVersion` is always `1` in this version of the skill. Bump when breaking the contract.

## When `status: success`

```json
{
  "schemaVersion": 1,
  "status": "success",
  "repository": { "path": "/data/repo", "revision": "abc123..." },
  "discovery": {
    "startedAt": "2026-07-01T10:00:00Z",
    "finishedAt": "2026-07-01T10:00:14Z",
    "agent": "pi/0.79.6",
    "skill": "test-discovery/0.1.0"
  },
  "suites": [ /* one or more suite objects */ ],
  "warnings": [ "optional short strings" ]
}
```

### repository

| Field | Type | Notes |
|---|---|---|
| `path` | string | absolute path to the cloned repo on disk |
| `revision` | string \| null | commit SHA if resolvable from `.git/HEAD` or the caller supplied it |

### discovery

| Field | Type | Notes |
|---|---|---|
| `startedAt` | ISO8601 string | UTC |
| `finishedAt` | ISO8601 string | UTC |
| `agent` | string | `pi/<version>` or equivalent |
| `skill` | string | `test-discovery/<skill-version>` |

### suites[]

Each detected (framework, workingDir) pair. Required fields marked with (R).

| Field | Type | Notes |
|---|---|---|
| `name` (R) | string | short slug, e.g. `playwright-e2e`, `go-unit`, `k6-load` |
| `framework` (R) | enum | see Framework enum below |
| `language` (R) | enum | `go`, `javascript`, `typescript`, `java`, `kotlin`, `python`, `rust`, `ruby`, `csharp`, `php`, `elixir`, `other` |
| `workingDir` (R) | string | absolute path, e.g. `/data/repo/e2e` |
| `configFile` | string \| null | path to the framework config file if present |
| `testFiles` | string[] | sample of test files, cap 10 entries; use `testFilesCount` for total |
| `testFilesCount` (R) | integer | number of test files matched |
| `testCommand` | string \| null | invocation, e.g. `npx playwright test` |
| `installCommand` | string \| null | dependency-install command, e.g. `npm ci` |
| `version` | string \| null | resolved framework version if known |
| `versionSource` (R) | enum | `lock`, `manifest_pinned`, `manifest_range`, `not_found` |
| `suggestedImage` | string \| null | container image hint, e.g. `mcr.microsoft.com/playwright:v1.49.0` |
| `templateHint` | string \| null | matching Testkube official template, e.g. `official/playwright/v1` |
| `envVars` | string[] | env var names referenced in test files |
| `artifactsHint` | string[] | glob paths for artifacts, e.g. `playwright-report/**` |
| `confidence` (R) | float 0-1 | see Confidence scoring in SKILL.md |
| `evidence` (R) | string[] | 2-4 short strings describing why this suite was detected |

## When `status: needs_input`

Emitted when the skill cannot make a clean determination without human/agent input.

```json
{
  "schemaVersion": 1,
  "status": "needs_input",
  "reason": "<enum>",
  "message": "<one-sentence explanation>",
  "context": { /* structured details */ }
}
```

### reason enum

| Value | When |
|---|---|
| `ambiguous_test_framework` | multiple frameworks are equally-supported by evidence in the same working dir |
| `multiple_workspaces_no_root` | monorepo with N workspaces and no clear entry point |
| `too_many_files` | repo file count exceeds the walk limit |
| `unknown_framework_high_signal` | strong signal of tests (many `*_test.*` files) but no known framework matched |

## When `status: error`

```json
{
  "schemaVersion": 1,
  "status": "error",
  "code": "<enum>",
  "message": "<one-sentence>"
}
```

### code enum

| Value | Meaning |
|---|---|
| `repo_not_found` | path does not exist or is not a directory |
| `repo_not_readable` | path exists but cannot be read (permissions) |
| `internal_error` | any other failure; message should include specifics |

## When `status: no_tests_found`

Walked the repo cleanly, but no test framework or test files were detected.

```json
{
  "schemaVersion": 1,
  "status": "no_tests_found",
  "repository": { "path": "/data/repo", "revision": "abc123..." },
  "discovery": { /* same as success */ },
  "checked": {
    "totalFiles": 47,
    "languagesDetected": ["typescript"],
    "reasons": ["short strings explaining what was and wasn't found"]
  }
}
```

## Framework enum

Fixed set. If you want to add a new value, edit the skill first, then this enum.

| Value | Notes |
|---|---|
| `playwright` | @playwright/test |
| `cypress` | cypress runner |
| `jest` | jest test runner |
| `vitest` | vitest test runner |
| `mocha` | mocha test runner |
| `k6` | k6 load test |
| `artillery` | artillery load test |
| `postman` | postman collection (Newman runtime) |
| `jmeter` | JMeter test plan |
| `go-test` | Go stdlib testing |
| `go-testify` | Go with testify (still uses `go test`, distinguish for reporting) |
| `pytest` | pytest |
| `unittest` | Python stdlib unittest |
| `maven-surefire` | Maven Surefire (JUnit under `src/test/java`) |
| `gradle-test` | Gradle `test` task |
| `cargo-test` | Rust cargo test |
| `rspec` | Ruby RSpec |
| `unknown` | fallback; must include `evidence[]` explaining |
