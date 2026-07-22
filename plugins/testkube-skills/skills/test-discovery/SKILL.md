---
name: test-discovery
description: >
  Walk a cloned repository, identify test files by framework and language, and report what was found in either a
  machine-readable JSON manifest or a human-readable Markdown report. Use when a repository has been cloned locally
  and you need to know what tests exist, what framework runs them, and what command executes them. The JSON output
  is consumed by programs (the testworkflow-author skill, cloud-api ingestion, CI); the Markdown output is meant for
  a person to read and opens cleanly in any plain-text editor. This skill does NOT execute tests, install
  dependencies, or write any TestWorkflow YAML — it observes and reports.
metadata:
  initiative: test-authoring
---

# test-discovery

Walk a cloned repository at the given path, identify the tests inside, and emit a structured JSON manifest describing
what was found. Output goes to stdout as a single JSON document. The consumer is typically the `testworkflow-author`
skill or the Testkube cloud-api discovery ingestion.

Scope:
- Read-only walk of the local filesystem
- Detect language and framework from marker files (config, manifest, lock files) and content signals
- Group findings into suites; a suite is one framework + one working directory
- Attach evidence + confidence to every suite
- Report ambiguity via `status: needs_input`; report failures via `status: error`

Out of scope: running tests, installing dependencies, writing TestWorkflow YAML, cloning repos, calling network APIs.

## Output contract (READ THIS FIRST)

The skill supports TWO output formats so the same discovery serves three kinds of consumer:

- **A program / machine** (the `testworkflow-author` skill, cloud-api ingestion, a CI step) → **JSON**. Parseable, schema-validated, no prose.
- **A person reading the result** → **Markdown**. Rendered headings, bullets, and fenced commands.
- **A plain-text editor** (someone opens the file in vim / VS Code / a diff view, no renderer) → **Markdown too**. It is plain UTF-8 text that stays readable unrendered — no JSON braces to parse by eye, no binary.

Pick the format based on the invocation:

**Default: JSON to stdout.** No prose, no markdown, no code fences. The output starts with `{` and ends with `}`. This is the format code consumers (cloud-api ingestion, downstream orchestrators) expect. Use this unless the invocation explicitly asks for markdown.

**Markdown when explicitly requested.** If the invocation prompt contains any of these signals, emit markdown instead:
- The literal phrase "output as markdown", "emit as markdown", "as markdown", or "format: markdown"
- An output path argument that ends in `.md` (e.g. "save to /data/artifacts/report.md")

**File output.** If the invocation gives an absolute path (any extension), also write the same content to that path. Format is inferred from the extension: `.md` → markdown, `.json` (or anything else) → JSON. Stdout always mirrors what's written to file.

**Both formats carry the same information.** JSON fields map 1:1 to markdown sections and bullet fields. See the two golden examples below.

**Every successful output must have this exact top-level shape:**

```json
{
  "schemaVersion": 1,
  "status": "success",
  "repository": { "path": "<absolute-path>", "revision": "<sha-or-null>" },
  "discovery": {
    "startedAt": "<ISO8601>",
    "finishedAt": "<ISO8601>",
    "agent": "pi/<version>",
    "skill": "test-discovery/0.1.0"
  },
  "suites": [ { /* one entry per (framework, workingDir), see below */ } ],
  "warnings": []
}
```

**Never add extra top-level keys.** Do not emit `testFramework`, `tests`, `module`, `language`, or any other field at the root — all detected data goes INSIDE `suites[]`.

**Never list individual test functions.** Group by (framework, workingDir). A repo with 28 `TestX` functions across 4 files under one Go module produces ONE suite with `testFilesCount: 4`, NOT 28 entries. Downstream consumers count files, not functions.

**Every suite must have every required field.** Required per suite: `name`, `framework`, `language`, `workingDir`, `testFilesCount`, `versionSource`, `confidence`, `evidence`. Optional but recommended: `configFile`, `testFiles` (sample, max 10), `testCommand`, `installCommand`, `version`, `suggestedImage`, `templateHint`, `envVars`, `artifactsHint`.

**Enum values only.** `framework`, `language`, and `versionSource` are enums. Any value outside the enum breaks schema validation. Common confusions to avoid:

- **`framework: "newman"`** is WRONG. Newman is the runner; the framework is `"postman"`.
- **`framework: "go test"`** is WRONG. Use `"go-test"` or `"go-testify"` (hyphen, not space).
- **`language: "json"`** is WRONG. There is no `json` language enum. Postman collections are JSON files but the correct language value is `"other"` (Postman is runtime-agnostic).
- **`language: "yaml"`** is WRONG. There is no `yaml` language enum. Artillery YAML is executed by a JavaScript runtime; use `"javascript"`. Same for any other YAML-configured JS-based tool.
- **`language: "java"`** for JMeter is acceptable because JMeter's runtime is Java, but `"other"` is also fine.
- **Framework `"unknown"`** is a fallback; use it only when no known framework matches and evidence is high.

Full enum lists live in `references/manifest-schema.md` and `assets/manifest-schema.json`. When in doubt, check.

**Golden example (a polyglot repo with 4 suites)** — copy this shape verbatim. Notice how EVERY suite has
`envVars` populated with real names and `artifactsHint` with framework defaults. Notice how the k6 suite
is detected via content-sniff in `perf/` even though the repo root has Playwright.

```json
{
  "schemaVersion": 1,
  "status": "success",
  "repository": { "path": "/data/repo", "revision": "abc123" },
  "discovery": {
    "startedAt": "2026-07-01T15:00:00Z",
    "finishedAt": "2026-07-01T15:00:07Z",
    "agent": "pi/0.79.6",
    "skill": "test-discovery/0.1.0"
  },
  "suites": [
    {
      "name": "go-unit",
      "framework": "go-testify",
      "language": "go",
      "workingDir": "/data/repo",
      "configFile": null,
      "testFiles": [
        "/data/repo/internal/users/service_test.go",
        "/data/repo/internal/auth/jwt_test.go"
      ],
      "testFilesCount": 10,
      "testCommand": "go test ./...",
      "installCommand": "go mod download",
      "version": "1.22",
      "versionSource": "manifest_pinned",
      "suggestedImage": "golang:1.22-alpine",
      "templateHint": null,
      "envVars": ["DATABASE_URL", "JWT_SECRET", "REDIS_URL"],
      "artifactsHint": ["coverage.out"],
      "confidence": 0.95,
      "evidence": [
        "go.mod at repo root with go 1.22 directive",
        "github.com/stretchr/testify v1.9.0 in go.sum",
        "10 files matching **/*_test.go across internal/, pkg/",
        "env vars os.Getenv(...) referenced in test files"
      ]
    },
    {
      "name": "web-vitest",
      "framework": "vitest",
      "language": "typescript",
      "workingDir": "/data/repo/web",
      "configFile": "/data/repo/web/vitest.config.ts",
      "testFiles": [
        "/data/repo/web/src/components/Button.test.tsx",
        "/data/repo/web/src/hooks/useAuth.test.ts"
      ],
      "testFilesCount": 4,
      "testCommand": "npm test",
      "installCommand": "npm ci",
      "version": "1.6.0",
      "versionSource": "lock",
      "suggestedImage": "node:22-alpine",
      "templateHint": null,
      "envVars": ["API_BASE_URL"],
      "artifactsHint": ["coverage/**"],
      "confidence": 0.95,
      "evidence": [
        "vitest.config.ts at web/",
        "vitest@1.6.0 in web/package-lock.json",
        "4 *.test.{ts,tsx} files under web/src/",
        "process.env.API_BASE_URL referenced in useAuth"
      ]
    },
    {
      "name": "e2e-playwright",
      "framework": "playwright",
      "language": "typescript",
      "workingDir": "/data/repo/e2e",
      "configFile": "/data/repo/e2e/playwright.config.ts",
      "testFiles": [
        "/data/repo/e2e/tests/login.spec.ts",
        "/data/repo/e2e/tests/checkout.spec.ts"
      ],
      "testFilesCount": 4,
      "testCommand": "npx playwright test",
      "installCommand": "npm ci",
      "version": "1.49.0",
      "versionSource": "lock",
      "suggestedImage": "mcr.microsoft.com/playwright:v1.49.0-noble",
      "templateHint": "official/playwright/v1",
      "envVars": ["BASE_URL", "TEST_USER"],
      "artifactsHint": ["playwright-report/**", "test-results/**"],
      "confidence": 0.95,
      "evidence": [
        "playwright.config.ts at e2e/",
        "@playwright/test@1.49.0 in e2e/package-lock.json",
        "4 *.spec.ts files under e2e/tests/",
        "process.env.BASE_URL and TEST_USER referenced in specs"
      ]
    },
    {
      "name": "perf-k6",
      "framework": "k6",
      "language": "javascript",
      "workingDir": "/data/repo/perf",
      "configFile": null,
      "testFiles": [
        "/data/repo/perf/checkout-load.js",
        "/data/repo/perf/api-spike.js",
        "/data/repo/perf/auth-burst.js"
      ],
      "testFilesCount": 3,
      "testCommand": "k6 run /data/repo/perf/checkout-load.js",
      "installCommand": null,
      "version": null,
      "versionSource": "not_found",
      "suggestedImage": "grafana/k6:0.49.0",
      "templateHint": "official/k6/v1",
      "envVars": ["TARGET_URL", "VUS", "DURATION", "API_URL", "API_TOKEN", "AUTH_URL", "JWT_SECRET"],
      "artifactsHint": [],
      "confidence": 0.75,
      "evidence": [
        "3 .js files under perf/ each importing from 'k6/http' in first 10 lines",
        "Makefile target test-perf invokes k6 run perf/checkout-load.js",
        "__ENV references in all three scripts extract 7 env var names"
      ]
    }
  ],
  "warnings": []
}
```

For alternate root shapes (`no_tests_found`, `needs_input`, `error`), see `references/manifest-schema.md`. Each has its own required-fields set.

### Markdown golden example (equivalent to the JSON above)

When emitting markdown, follow this exact section structure. Every JSON field maps to a bullet or section header; do not skip fields. Use fenced code blocks for commands. Never emit JSON when in markdown mode.

```markdown
# Test Discovery Report

- **Status**: success
- **Schema version**: 1
- **Skill**: test-discovery/0.1.0
- **Agent**: pi/<version>

## Repository

- **Path**: /data/repo
- **Revision**: abc123

## Discovery

- **Started**: 2026-07-01T15:00:00Z
- **Finished**: 2026-07-01T15:00:07Z

## Suites

### go-unit (confidence 0.95)

- **Framework**: go-testify
- **Language**: go
- **Working dir**: /data/repo
- **Config file**: (none)
- **Test files count**: 10
- **Test command**: `go test ./...`
- **Install command**: `go mod download`
- **Version**: 1.22 (manifest_pinned)
- **Suggested image**: `golang:1.22-alpine`
- **Template hint**: (none)
- **Env vars**: `DATABASE_URL`, `JWT_SECRET`, `REDIS_URL`
- **Artifacts hint**: `coverage.out`

**Evidence**:

- go.mod at repo root with go 1.22 directive
- github.com/stretchr/testify v1.9.0 in go.sum
- 10 files matching `*_test.go` across `internal/`, `pkg/`
- env vars via `os.Getenv(...)` referenced in test files

### web-vitest (confidence 0.95)

... (same shape as above; one section per suite)

## Warnings

- (none)
```

For alternate statuses in markdown:

- `no_tests_found`: no `## Suites` section; add `## Checked` with `Total files`, `Languages detected`, and `Reasons` fields
- `needs_input`: no `## Suites`; add `## Needs Input` with `Reason`, `Message`, and `Context` (structured bullet list)
- `error`: no `## Suites`; add `## Error` with `Code` and `Message`

All markdown outputs MUST include the top-level `Status`, `Schema version`, `Skill`, `Agent` bullets. Same required fields per suite as the JSON schema.

## The Core Loop

Every discovery task follows this sequence:

1. **Confirm the working directory** — take the path from the invocation prompt. Default to `/data/repo` when the
   caller does not specify. If the path does not exist or is not a directory, emit `status: error` with code
   `repo_not_found` and stop.
2. **Walk the tree** — list files up to a reasonable depth (skip `node_modules/`, `vendor/`, `.git/`, `dist/`,
   `build/`, `.venv/`, `target/`, `.gradle/`, `.next/`, `.turbo/`, `.pytest_cache/`, `__pycache__/`, `.tox/`,
   `bin/`, `obj/`). Cap at ~10k files considered; if exceeded, note in `warnings[]` and prioritize root + common
   test dirs (`test/`, `tests/`, `spec/`, `e2e/`, `__tests__/`).
3. **Detect deterministically first** — apply the framework signals in `references/framework-signals.md`. Each signal
   is: (marker file → framework). This is where 80% of detections come from. Order does not matter here — apply all.
4. **Content-sniff second** — for `.js`/`.ts` files where the language is ambiguous, read the first 100 lines and
   check for imports (`from 'k6/http'`, `from 'k6'`, `from 'puppeteer'`, `import { test } from '@playwright/test'`,
   etc). This catches k6/Puppeteer/inline test runners.
5. **Read manifests and lock files** — for every detected framework, read `package.json`, `go.mod`, `pom.xml`,
   `build.gradle`, `requirements.txt`, `pyproject.toml`, `Cargo.toml`, `Gemfile` for framework version and scripts;
   read `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `go.sum`, `poetry.lock` for the exact resolved version.
6. **Extract test command** — prefer explicit scripts from the manifest (npm `scripts.test`, Makefile `test:` target,
   `tox.ini` env, `[project.scripts]` in pyproject.toml). Fall back to the framework's default command.
7. **Extract env vars** — scan test files for common env-var patterns (`process.env.X`, `${X}`, `os.getenv("X")`).
   Report unique names, no values.
8. **Group into suites** — one suite per (framework, workingDir) tuple. Multiple test files under the same working
   directory with the same framework collapse into one suite. If the same working directory has two different
   frameworks (e.g. `unit/` has jest, `e2e/` has playwright), they are two suites.
9. **Score confidence per suite** — see the Confidence section below.
10. **Verification passes (mandatory before emit).** Before emitting the manifest, confirm you did each pass
    below. If you skipped one, do it now.

    - **Content sniff for k6 in perf-like dirs.** For every `.js` file under directories named `perf/`, `load/`,
      `benchmarks/`, `k6/`, `stress/`, `smoke/`, or `bench/` (case-insensitive), read the first 100 lines and
      check for `import ... from 'k6'`, `import ... from 'k6/http'`, or `require('k6...`. If matched, that
      directory is a k6 suite. **Do NOT skip this pass just because you already found Playwright/Cypress/Vitest
      at the repo root.** A repo can have BOTH.
    - **Makefile + package.json scripts scan for runner invocations.** Read the `Makefile` and every
      `package.json`'s `scripts` block. If any target/script literally invokes `k6`, `artillery`, `jmeter`, or
      `newman`, that framework is present even if no config file matched. Treat the invoked file path (or the
      containing directory) as a member of that suite.
    - **Go framework classification: grep `go.sum` for assertion libraries.** If `github.com/stretchr/testify`
      is in `go.sum`, framework is `go-testify` (NOT `go-test`). Include evidence: "testify vX.Y.Z in go.sum".
      If `github.com/onsi/ginkgo` is present, still `go-test` but note in evidence.
    - **Env var extraction per suite (mandatory).** For each suite, scan its test files for the language-specific
      env var patterns from `references/detection-heuristics.md`. Common patterns: JS/TS `process.env.X` and
      `import.meta.env.X`; k6 `__ENV.X`; Go `os.Getenv("X")`; Python `os.environ["X"]`. Deduplicate, sort, cap
      at 20. If truly none found, still add an evidence entry "no env vars referenced in test files"; do NOT
      silently leave `envVars: []`.
    - **Artifacts hint per suite from framework defaults.** Look up the framework's default `artifactsHint` from
      `references/framework-signals.md`. Do NOT emit empty for frameworks that have known defaults. Common ones:

      | Framework | Default `artifactsHint` |
      |---|---|
      | Playwright | `["playwright-report/**", "test-results/**"]` |
      | Cypress | `["cypress/screenshots/**", "cypress/videos/**"]` |
      | Jest | `["coverage/**", "junit.xml"]` |
      | Vitest | `["coverage/**"]` |
      | Go stdlib / testify | `["coverage.out"]` |
      | pytest | `["htmlcov/**", "coverage.xml"]` |
      | Maven Surefire | `["target/surefire-reports/**"]` |
      | Gradle Test | `["build/reports/tests/**", "build/test-results/**"]` |
      | Postman (Newman) | `["newman/**"]` |
      | JMeter | `["results.jtl", "report/**"]` |
      | Artillery | `["report.json", "report.html"]` |
      | k6 | `[]` (stdout-only unless script uses `--out`) |

11. **Choose the output format from the invocation.**
    - Default: JSON. Emit exactly one JSON document to stdout matching `references/manifest-schema.md`.
    - Markdown when explicitly requested (phrases like "output as markdown", "emit as markdown", "as markdown",
      "format: markdown", or a target path ending in `.md`). Emit exactly the markdown template shown above,
      with every JSON field mapped to a bullet or section. Never mix formats.
    - If an absolute file path is given (any extension), also write the same content to that path. Extension
      infers format (`.md` → markdown, `.json` or other → JSON). Stdout always mirrors the file content.

12. **Emit.** Write the chosen format to stdout. Do not emit any commentary before or after. If a target file
    path was given, also write to that path.

## Rules

Mandatory. Violating any of these produces a broken manifest that downstream consumers will reject.

0. **MUST match the requested output format.** Default is JSON to stdout, matching `assets/manifest-schema.json`
   exactly (no extra top-level keys, no missing required keys, no re-namings). If the invocation asks for markdown
   (explicit phrase or `.md` path), emit markdown following the golden example above (all required sections,
   every JSON field mapped to a bullet or subsection). NEVER mix formats. If a file path is given, also write
   the same content to that path; format is inferred from the extension.

1. **MUST NOT execute any command.** No `npm ci`, no `go test`, no `jest --listTests`. Discovery is a filesystem walk
   only. If you don't know something without executing code, mark low confidence and add evidence.

2. **MUST read lock files to determine resolved framework versions.** A `package.json` says `"@playwright/test":
   "^1.49.0"` but the resolved version could be anything in the range. Read `package-lock.json`,
   `pnpm-lock.yaml`, or `yarn.lock`. For Go, read `go.sum`. For Python, read `poetry.lock` or `requirements.txt`
   pins. If no lock file exists, report the manifest range and set `versionSource: "manifest_range"` in the suite;
   downstream will pick a safe default image.

3. **MUST NOT invent test commands.** If the manifest doesn't have `scripts.test`, use the framework's canonical
   default (e.g. `npx playwright test`). Never fabricate a command based on directory names or wishful thinking.

4. **MUST attach evidence to every suite.** The `evidence[]` array is what a human uses to sanity-check the AI's
   inference. Every suite includes 2-4 short strings like "playwright.config.ts present at e2e/",
   "@playwright/test@1.49.0 in package-lock.json", "e2e/tests/*.spec.ts pattern (3 files)".

5. **MUST group by (framework, workingDir), NOT by file and NOT by test function.** A repo with 47 `*.spec.ts`
   files under `e2e/tests/` produces ONE suite (`e2e`), not 47. A Go repo with 28 `TestX` functions across 4
   `_test.go` files under one module produces ONE suite with `testFilesCount: 4`, NOT 28 entries. NEVER enumerate
   individual test function names in the output — downstream consumers only need file counts. A monorepo with
   `apps/web/e2e/` (playwright) and `services/api/tests/` (jest) produces TWO suites.

6. **MUST include a `confidence` float 0.0-1.0 per suite** based on the scoring rubric below. Downstream uses this
   to decide whether to run automatically vs prompt the user.

7. **MUST emit exactly one JSON document to stdout.** Do not wrap in markdown, do not prepend commentary. The
   entire stdout must be parseable as JSON. Diagnostic messages go to stderr if needed.

8. **MUST report ambiguity via `status: needs_input`**, not by guessing. If `package.json` lists both `jest` and
   `vitest` as devDependencies, emit `needs_input` with a `reason` and the options — do not pick one silently.

9. **MUST perform the env var extraction pass per suite.** Empty `envVars: []` is only acceptable if you
   explicitly scanned the test files and found no references. Never leave it empty by omission. Same discipline
   for `artifactsHint`: populate from the framework's known defaults in `framework-signals.md` — do not skip
   because you did not look up the reference.

10. **MUST NOT skip content-sniff detection when marker files exist elsewhere.** A repo can have Playwright at
    the root AND k6 under `perf/`. Detecting the marker-file framework does not exempt you from sniffing content-
    based frameworks in perf-like directories. If you find Playwright, that does NOT mean you can stop looking.
    Also cross-check any `Makefile` or `scripts.test` for `k6`/`artillery`/`jmeter`/`newman` invocations that
    reveal frameworks with no dedicated config file.

## Decision Tree

### Language identification

```
Which marker files does the root have?
├── go.mod                      → Go
├── package.json                → JavaScript or TypeScript (check for tsconfig.json to distinguish)
├── pom.xml                     → Java (Maven)
├── build.gradle(.kts)          → Java or Kotlin (Gradle)
├── requirements.txt            → Python
├── pyproject.toml              → Python (modern)
├── Pipfile                     → Python
├── Cargo.toml                  → Rust
├── Gemfile                     → Ruby
├── composer.json               → PHP
├── mix.exs                     → Elixir
├── *.csproj / *.sln            → C# / .NET
└── (none)                      → walk deeper; multi-language monorepo possible
```

### Framework identification (top-down after language is known)

See `references/framework-signals.md` for the full detection matrix. Highest-signal markers:

| If you see | Framework is | Language |
|---|---|---|
| `playwright.config.{js,ts,mjs}` OR `@playwright/test` dep | Playwright | JS/TS |
| `cypress.config.{js,ts}` OR `cypress.json` OR `cypress` dep | Cypress | JS/TS |
| `.jmx` file | JMeter | Java (runtime) |
| `.postman_collection.json` OR `info.schema` contains `getpostman.com` | Postman | Any (Newman runtime) |
| `.js` file with `from 'k6'` or `from 'k6/http'` | k6 | JS (k6 runtime) |
| `.yaml` file with top-level `scenarios:` and `config.target:` | Artillery | JS (Artillery runtime) |
| `pom.xml` with `maven-surefire-plugin` OR `src/test/java/**` | Maven Surefire | Java |
| `build.gradle` with `test { }` task OR `src/test/java/**` | Gradle Test | Java/Kotlin |
| `*_test.go` files | Go stdlib testing | Go |
| `jest.config.{js,ts,json}` OR `jest` dep OR `*.test.{js,ts}` with `describe(`/`it(` | Jest | JS/TS |
| `vitest.config.{js,ts}` OR `vitest` dep | Vitest | JS/TS |
| `.mocharc.{json,js,yml}` OR `mocha` dep | Mocha | JS/TS |
| `pytest.ini` OR `pyproject.toml [tool.pytest]` OR `test_*.py` OR `*_test.py` | pytest | Python |
| `unittest`-style `test_*.py` with `unittest.TestCase` (no pytest markers) | unittest | Python |
| `Cargo.toml` with `[dev-dependencies]` + `tests/**/*.rs` OR `#[test]` in `src/**` | cargo test | Rust |
| `*_spec.rb` under `spec/` + `Gemfile` with `rspec` | RSpec | Ruby |

## Version extraction

Priority order for each detected framework:

1. **Lock file** (authoritative): `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `go.sum`, `poetry.lock`,
   `Gemfile.lock`, `Cargo.lock`. Extract the exact resolved version.
2. **Manifest pinned version**: exact version in `package.json` `dependencies` / `devDependencies` (no `^`, `~`,
   `>=`).
3. **Manifest range**: `^1.49.0`, `~1.49`, `>=1.0`. Report as-is; downstream picks a safe image.
4. **No version signal**: omit `version` field; downstream uses the framework's fallback image.

Set `versionSource` to one of: `"lock"`, `"manifest_pinned"`, `"manifest_range"`, `"not_found"`.

## Confidence scoring

Assign per-suite confidence from evidence strength. Not a real probability, just a comparable score for
downstream.

| Evidence combination | Confidence |
|---|---|
| Config file present + framework in lock file + tests match convention | 0.95 |
| Config file present + framework in manifest (range) + tests match convention | 0.85 |
| Framework in manifest + tests match convention, no config file | 0.75 |
| Content sniff only (e.g. k6 imports in .js) | 0.65 |
| Framework in manifest + no test files found in conventional locations | 0.45 |
| Marker file only, no other evidence | 0.35 |

Round to 2 decimals.

## Output Format

Emit exactly one JSON document to stdout. Full schema in `references/manifest-schema.md`. Root shape:

```json
{
  "schemaVersion": 1,
  "status": "success",
  "repository": {
    "path": "/data/repo",
    "revision": "<commit sha if available, else null>"
  },
  "discovery": {
    "startedAt": "<ISO8601>",
    "finishedAt": "<ISO8601>",
    "agent": "pi/<version>",
    "skill": "test-discovery/0.1.0"
  },
  "suites": [ { "...": "see manifest-schema.md" } ],
  "warnings": [ "<optional short strings>" ]
}
```

### Alternate root shapes

`status: needs_input` — ambiguous detection that requires human/agent input:

```json
{
  "schemaVersion": 1,
  "status": "needs_input",
  "reason": "<enum, see manifest-schema.md>",
  "message": "<human-readable, one sentence>",
  "context": { "...": "structured details" }
}
```

`status: error` — could not complete discovery:

```json
{
  "schemaVersion": 1,
  "status": "error",
  "code": "<enum, see manifest-schema.md>",
  "message": "<human-readable, one sentence>"
}
```

`status: no_tests_found` — walked repo cleanly but found nothing that looks like tests:

```json
{
  "schemaVersion": 1,
  "status": "no_tests_found",
  "repository": { "...": "..." },
  "discovery": { "...": "..." },
  "checked": {
    "totalFiles": 47,
    "languagesDetected": ["typescript"],
    "reasons": ["no known test framework markers", "no *.test.ts or *.spec.ts files under conventional dirs"]
  }
}
```

## Gotchas

- **Content sniffing has false positives.** A `.js` file mentioning `k6` in a comment or a variable name is NOT
  a k6 test file. Only match `import ... from 'k6...'`, `require('k6...`, or `from "k6"`. Use word boundaries.
- **Monorepo package.json ambiguity.** A root `package.json` in a Yarn/pnpm/npm workspaces monorepo may list
  dev dependencies for many sub-packages. Prefer per-workspace `package.json` for framework attribution when
  the config file is inside a workspace.
- **playwright vs @playwright/test.** The runnable framework is `@playwright/test`. The `playwright` package
  alone is the library (used by `@playwright/test` internally). Distinguish.
- **Java without Maven/Gradle.** A `src/test/java/**` layout without a build tool is legal (raw `javac`). Rare.
  Emit a low-confidence suite with `testCommand: null` and evidence-only.
- **Multi-tool JS/TS repos.** A repo can have Jest for unit + Playwright for e2e + k6 for load — all valid, all
  separate suites. Do NOT collapse.
- **Vendored dependencies.** `vendor/` (Go), `node_modules/` (JS), `.venv/` (Python) — skip. They contain third-
  party tests that are not the user's tests.
- **Generated / minified files.** `*.min.js`, `dist/`, `build/` — skip. They contain code but not tests.
- **Test files inside `examples/` or `demo/`.** Case-by-case. If the parent repo's `README` says these are
  runnable, include with a warning; otherwise skip.
- **k6 lives in `.js` files.** k6 uses JS syntax but is a completely separate runtime. Detection is content-only
  via imports; the file is not a Node.js test file even if the extension is `.js`.
- **Artillery uses YAML, not JS.** Common signal is `artillery.yml` / `.artillery.yaml` with `config.target` and
  `scenarios[]`. Sometimes has an accompanying `.js` processor — do not classify that as a k6 file. Language enum
  value for Artillery suites is `"javascript"` (Artillery is a JS-based tool), NOT `"yaml"`.
- **Postman collections are JSON but language is not `json`.** Correct `language` for Postman suites is `"other"`.
  Correct `framework` is `"postman"`, NOT `"newman"` (Newman is the runner CLI, not the framework).
- **Cypress suggested image is `cypress/included:<version>`**, not `cypress/base:*`. `cypress/included` bundles
  the runner + browsers + Node; `cypress/base` is a lower-level image that needs manual Cypress install.
  Example: for `cypress@13.16.1`, `suggestedImage: "cypress/included:13.16.1"`.
- **JMeter binary/XML files.** `.jmx` files are XML but not readable-in-shell; do NOT try to parse them for env
  vars beyond simple regex on the raw text.

## Reference Index

Load these on demand.

| Reference | When to Load |
|---|---|
| `references/manifest-schema.md` | When writing the output JSON; contains every field, type, and enum value |
| `references/detection-heuristics.md` | When a framework is ambiguous or you need edge-case handling |
| `references/framework-signals.md` | When you need the full "marker file to framework" table |
| `assets/manifest-schema.json` | When validating output externally (JSON Schema, draft-07) |
| `examples/*.json` | When you need a concrete output example for a scenario (single-framework, monorepo, empty, novel) |
