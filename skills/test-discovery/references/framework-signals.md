# framework signals

Dense reference table: what to look for, in what order, and what to emit. Load when SKILL.md's Decision Tree is
not specific enough.

## Legend

- **Marker (R)** = highest-priority signal. If present, the framework is nearly certainly used.
- **Marker (H)** = strong heuristic. Combined with a test-file pattern match, treat as detected.
- **Marker (L)** = weak. Only reliable when combined with several other signals.
- **Command hints** = the default test command when no override is found in the manifest scripts.

## Playwright

| Signal | Weight |
|---|---|
| `playwright.config.{js,ts,mjs,cjs}` in any dir | R |
| `@playwright/test` in `package.json` dependencies or devDependencies | R |
| `import { test } from '@playwright/test'` in a `.ts` or `.js` file | H |
| `*.spec.ts` or `*.spec.js` under a directory that also has `playwright.config.*` | H |

- Working dir: directory containing `playwright.config.*`
- Test file pattern: `*.spec.{js,ts,mjs}` or `tests/**/*.spec.*`
- Version source: `package-lock.json` → `node_modules/@playwright/test` version key; else `package.json` range
- Default install: `npm ci` (or `pnpm install --frozen-lockfile` / `yarn install --frozen-lockfile` based on lock file)
- Default test command: `npx playwright test`
- Suggested image pattern: `mcr.microsoft.com/playwright:v<major.minor.patch>-noble`
- Template hint: `official/playwright/v1`
- Common env vars: `BASE_URL`, `PLAYWRIGHT_JUNIT_OUTPUT_NAME`, `PLAYWRIGHT_HTML_REPORT`, `CI`
- Artifact hints: `playwright-report/**`, `test-results/**`, `traces/**`

## Cypress

| Signal | Weight |
|---|---|
| `cypress.config.{js,ts,mjs,cjs}` in any dir | R |
| `cypress.json` (legacy config, pre v10) | R |
| `cypress` in `package.json` dependencies or devDependencies | H |
| `cypress/e2e/**/*.cy.{js,ts}` files present | H |

- Working dir: directory containing the config
- Test file pattern: `cypress/e2e/**/*.cy.{js,ts}` or `cypress/integration/**/*.spec.{js,ts}` (legacy)
- Version source: same priority as Playwright
- Default install: same as Playwright
- Default test command: `npx cypress run`
- Suggested image pattern: `cypress/included:<major.minor.patch>`
- Template hint: `official/cypress/v1`
- Common env vars: `CYPRESS_BASE_URL`, `CYPRESS_baseUrl`, `CYPRESS_*` any
- Artifact hints: `cypress/screenshots/**`, `cypress/videos/**`, `cypress/reports/**`

## Jest

| Signal | Weight |
|---|---|
| `jest.config.{js,ts,mjs,cjs,json}` | R |
| `jest` key in `package.json` | R |
| `jest` in `devDependencies` | H |
| `*.test.{js,ts,jsx,tsx}` or `*.spec.{js,ts,jsx,tsx}` files present | H |
| `__tests__/` directories | H |

- Working dir: package root (where `package.json` lives)
- Test file pattern: `**/*.test.{js,ts,jsx,tsx}`, `**/*.spec.{js,ts,jsx,tsx}`, `**/__tests__/**/*.{js,ts,jsx,tsx}`
- Default test command: `npm test` if `scripts.test` runs jest; else `npx jest`
- Suggested image: `node:<lts>` (e.g. `node:22-alpine`)
- Template hint: none (no official Jest template today; leave `null`)
- Common env vars: `NODE_ENV`, `CI`, `JEST_JUNIT_OUTPUT_DIR`, `JEST_JUNIT_OUTPUT_NAME`
- Artifact hints: `coverage/**`, `junit.xml`

## Vitest

| Signal | Weight |
|---|---|
| `vitest.config.{js,ts,mjs,cjs}` | R |
| `vitest` in dependencies or devDependencies | H |
| `test:` script in `package.json` invoking `vitest` | H |

- Working dir: package root
- Test file pattern: same as Jest (`*.test.*`, `*.spec.*`)
- Default test command: `npx vitest run` (single-run, non-watch)
- Suggested image: `node:<lts>`
- Template hint: none
- Artifact hints: `coverage/**`

## Mocha

| Signal | Weight |
|---|---|
| `.mocharc.{json,js,cjs,yml,yaml}` | R |
| `mocha` in dependencies/devDependencies | H |
| `test:` script invoking `mocha` | H |

- Working dir: package root
- Test file pattern: `test/**/*.{js,ts}`, `*.test.{js,ts}`
- Default test command: `npx mocha`
- Suggested image: `node:<lts>`
- Template hint: none

## k6

Detection is content-only: file extension `.js` with imports from `k6*`.

| Signal | Weight |
|---|---|
| First 100 lines of a `.js` file contain `from 'k6'`, `from "k6"`, `from 'k6/http'`, or `require('k6...` | H |

Do NOT match on the substring `k6` alone; that produces false positives (variables, comments).

- Working dir: directory containing the k6 script
- Test file pattern: any `.js` that matches the import signal above
- Default test command: `k6 run <script.js>`
- Suggested image: `grafana/k6:<version>` (fallback `grafana/k6:0.49.0`)
- Template hint: `official/k6/v1`
- Common env vars: any referenced via `__ENV.NAME` in the script
- Artifact hints: none by default (k6 output is stdout unless `--out` is configured)

## Artillery

| Signal | Weight |
|---|---|
| `.artillery.{yaml,yml}` or `artillery.yml` or `artillery-config.{yml,yaml}` | R |
| YAML with top-level `scenarios:` and `config.target:` | R |
| `artillery` in `package.json` (if installed via npm) | H |

- Working dir: directory containing the YAML config
- Test file pattern: the YAML file itself; optional companion `.js` processor
- Default test command: `artillery run <config.yml>`
- Suggested image: `artilleryio/artillery:<version>` (fallback `artilleryio/artillery:latest`)
- Template hint: none today
- Artifact hints: `report.json`, `report.html`

## Postman

| Signal | Weight |
|---|---|
| Any `.json` file with `info.schema` containing `getpostman.com/collection` | R |
| Filename matches `*.postman_collection.json` | H |

- Working dir: directory containing the collection
- Test file pattern: the collection JSON itself, plus optional `*.postman_environment.json`
- Default test command: `newman run <collection.json>` (add `-e <env.json>` if env file present)
- Suggested image: `postman/newman:6-alpine`
- Template hint: `official/postman/v1`
- Artifact hints: `newman/**`

## JMeter

| Signal | Weight |
|---|---|
| `.jmx` file (XML, JMeter test plan) | R |

- Working dir: directory containing the `.jmx`
- Test file pattern: `*.jmx`
- Default test command: `jmeter -n -t <file.jmx> -l /data/artifacts/results.jtl`
- Suggested image: `justb4/jmeter:<version>` (fallback `justb4/jmeter:5.5`)
- Template hint: `official/jmeter/v1`
- Artifact hints: `results.jtl`, `report/**`

## Maven Surefire (Java)

| Signal | Weight |
|---|---|
| `pom.xml` in a directory | R |
| `src/test/java/**/*.java` under the same directory | H |
| `maven-surefire-plugin` in the `pom.xml` build/plugins | H |

- Working dir: directory containing `pom.xml`
- Test file pattern: `src/test/java/**/*.java`
- Version source: parse `pom.xml`, look for `org.apache.maven:maven-core` in dependencies or the `maven-compiler-plugin` version
- Default test command: `mvn test`
- Suggested image: `maven:<version>` (fallback `maven:3.9`)
- Template hint: `official/maven/v1`
- Common env vars: `JAVA_OPTS`, `MAVEN_OPTS`
- Artifact hints: `target/surefire-reports/**`

## Gradle Test (Java/Kotlin)

| Signal | Weight |
|---|---|
| `build.gradle` or `build.gradle.kts` | R |
| `src/test/java/**` or `src/test/kotlin/**` | H |

- Working dir: directory containing `build.gradle`
- Test file pattern: `src/test/{java,kotlin}/**/*.{java,kt}`
- Version source: not extracted (Gradle wrapper handles it); check `gradle/wrapper/gradle-wrapper.properties` if version signal needed
- Default test command: `./gradlew test` (or `gradle test` if no wrapper)
- Suggested image: `gradle:jammy`
- Template hint: `official/gradle/v1`
- Artifact hints: `build/reports/tests/**`, `build/test-results/**`

## Go stdlib testing / testify

| Signal | Weight |
|---|---|
| `go.mod` | R |
| `*_test.go` files anywhere in the tree | R |
| `github.com/stretchr/testify` in `go.sum` (drives framework classification: `go-testify` vs `go-test`) | R |

- Working dir: repo root (where `go.mod` lives); if monorepo with multiple modules, one suite per module
- Test file pattern: `**/*_test.go`
- Version source: `go.mod` `go X.Y` directive for the Go language version
- Default test command: `go test ./...`
- Suggested image: `golang:<X.Y>-alpine` derived from `go.mod`
- Template hint: none today (Testkube has generic Go template? verify)
- Common env vars: reference `os.Getenv(...)` scans
- Artifact hints: `coverage.out` (if `-coverprofile` is used)
- Framework value: use `go-testify` when `testify` is in `go.sum`, else `go-test`

## pytest

| Signal | Weight |
|---|---|
| `pytest.ini` | R |
| `pyproject.toml` with `[tool.pytest.ini_options]` | R |
| `pytest` in `requirements.txt` or `pyproject.toml [tool.poetry.dev-dependencies]` | H |
| `test_*.py` or `*_test.py` files | H |
| `conftest.py` present | H |

- Working dir: directory containing the config (or `pyproject.toml`)
- Test file pattern: `test_*.py`, `*_test.py`, `tests/**/*.py`
- Version source: `poetry.lock` or `requirements.txt` pin
- Default test command: `pytest -q`
- Suggested image: `python:<X.Y>` derived from `pyproject.toml [tool.poetry.dependencies] python`
- Template hint: none today
- Common env vars: standard `os.environ[...]` scans
- Artifact hints: `htmlcov/**`, `coverage.xml`, `.pytest_cache/` (skip caching artifacts)

## Python unittest (stdlib)

Use only when pytest signals are absent but Python test files exist.

| Signal | Weight |
|---|---|
| `test_*.py` with `import unittest` and `class ... (unittest.TestCase)` | H |
| No `pytest` in manifest | L (negative) |

- Working dir: repo root or `tests/`
- Test file pattern: `test_*.py`
- Default test command: `python -m unittest discover`
- Suggested image: `python:<X.Y>` from `.python-version` or `pyproject.toml`
- Template hint: none

## Cargo test (Rust)

| Signal | Weight |
|---|---|
| `Cargo.toml` | R |
| `tests/**/*.rs` directory | H |
| `#[test]` attribute in `src/**/*.rs` | H |

- Working dir: directory containing `Cargo.toml`
- Test file pattern: `tests/**/*.rs` (integration), `src/**/*.rs` files with `#[cfg(test)]` blocks (unit)
- Default test command: `cargo test`
- Suggested image: `rust:<version>` derived from `rust-toolchain.toml` or `Cargo.toml` `rust-version`
- Template hint: none
- Artifact hints: `target/tarpaulin/**` if tarpaulin config found

## RSpec (Ruby)

| Signal | Weight |
|---|---|
| `.rspec` config file | R |
| `spec/spec_helper.rb` | R |
| `rspec-rails` or `rspec` in `Gemfile` | H |
| `spec/**/*_spec.rb` files | H |

- Working dir: repo root
- Test file pattern: `spec/**/*_spec.rb`
- Default test command: `bundle exec rspec`
- Suggested image: `ruby:<version>` derived from `.ruby-version` or `Gemfile`
- Template hint: none

## Fallback: unknown framework

If a repo has strong test-file signals (e.g. many `*_test.*` files) but no known framework matches, emit ONE
suite with `framework: "unknown"`, low confidence (0.35), a null `testCommand`, and the evidence array
listing what you saw. Also emit a `warnings[]` entry with a suggestion for the user to look at.
