# detection heuristics

Load when a framework is ambiguous, when you need to pick among competing signals, or when you need to handle
edge cases that don't fit the simple "marker → framework" table in `framework-signals.md`.

## Signal priority

When multiple signals exist for competing frameworks in the same working directory, use this priority order:

1. **Config file wins over dep-list.** If `playwright.config.ts` and `jest.config.js` both live in `apps/web/`,
   they're both real, and you emit TWO suites (one per config). Never fold one into the other.
2. **Lock file version wins over manifest range.** A `package.json` saying `"jest": "^28.0.0"` and a
   `package-lock.json` saying `29.7.0` produces `version: "29.7.0"`, `versionSource: "lock"`.
3. **Deeper config beats shallower config.** In `apps/web/playwright.config.ts` + `playwright.config.ts` at
   root, prefer the deeper one as authoritative for its directory. Root is separate.
4. **Content sniff loses to marker file.** A `.js` file with `import ... from 'k6'` next to a
   `playwright.config.ts` in the same dir — that dir is Playwright. The k6 file is a false positive (probably
   a k6 test file inside a Playwright project, but the wrapping directory is Playwright). Emit ONE suite
   (Playwright) and add a warning about the ambiguous k6 file.

## Monorepo handling

Common structures the skill must handle:

### npm/pnpm/yarn workspaces

Signals:
- Root `package.json` has `"workspaces": [...]` (npm/yarn)
- `pnpm-workspace.yaml` (pnpm)
- Multiple sub-`package.json` files

Approach:
- Walk the top-level workspace paths and treat each as its own package
- Emit one suite per (workspace, framework) match; do NOT collapse across workspaces
- Working dir = the workspace path, not the repo root

### Nx / Turborepo / Rush

Signals:
- `nx.json` OR `turbo.json` OR `rush.json`

Approach:
- Same as npm workspaces: iterate packages, emit per-workspace suites
- These tools have opinionated task graphs but from a discovery perspective the framework detection is
  identical to a plain workspace repo

### Multi-language monorepos

Signal: multiple top-level marker files (e.g. `go.mod` AND `package.json` AND `pom.xml`)

Approach:
- Detect each language independently
- Emit suites for each; a repo with Go tests + Playwright e2e + Java integration tests emits three suites

## Ambiguity → `needs_input`

Emit `status: needs_input` when the skill cannot make a determination without dropping evidence. Real cases:

### Jest OR Vitest (both configured)

If `package.json` has both `jest` and `vitest` in devDependencies and both have config files, EMIT BOTH
suites (they're both real). This is NOT needs_input — it's two different test runners for two different
purposes.

### Jest AND Vitest in `scripts.test` (only one runs)

If `scripts.test` is `"jest"` and vitest is in devDependencies but with no config or entry, emit ONE suite
for Jest and add a warning about the vestigial vitest dep.

### Ambiguous script

If `scripts.test` is `"npm run build && npm run test:unit && npm run test:e2e"` and the sub-scripts are
unknown, emit `needs_input` with `reason: ambiguous_test_framework` and `context.script` containing the
full chain.

### Unknown high-signal framework

If there are many `test_*.py` files but no pytest / unittest / nose / trial markers, emit `needs_input`
with `reason: unknown_framework_high_signal`, `context.language: "python"`,
`context.candidateFiles: [...]`, `context.suggestion: "check pyproject.toml or ask user about test runner"`.

## Version resolution edge cases

### Semver ranges with pre-release tags

`"@playwright/test": "^1.49.0-rc.1"` → treat pre-release as unpinned. Use `versionSource: "manifest_range"`
and either report the pre-release version or fall back to the fallback image.

### Local file dependencies

`"@internal/tests": "file:../shared-tests"` → skip for version extraction; note in warnings.

### Git dependencies

`"my-fork-of-playwright": "git+https://..."` → skip for version extraction; note in warnings.

### Multiple installed versions (npm ls tree)

`package-lock.json` may have multiple resolved versions of a package (peer deps, transitive). Use the
TOP-LEVEL install version (the entry directly under `node_modules/@playwright/test`), not a nested one.

## Test-file pattern matching

Patterns are relative to the suite's `workingDir` and follow gitignore-style globs.

### Correct patterns

- Playwright: `**/*.spec.{js,ts,mjs}` (Playwright convention is `.spec.*`)
- Cypress: `cypress/e2e/**/*.cy.{js,ts}` (v10+), `cypress/integration/**/*.spec.{js,ts}` (pre-v10)
- Jest: `**/*.test.{js,ts,jsx,tsx}`, `**/*.spec.{js,ts,jsx,tsx}`, `**/__tests__/**/*.{js,ts}`
- Go: `**/*_test.go`
- pytest: `test_*.py`, `*_test.py`
- RSpec: `spec/**/*_spec.rb`

### Common pitfalls

- **Playwright `.spec.ts` vs Jest `.test.ts`**: convention only, both frameworks accept both patterns.
  Config file location determines assignment.
- **Do not match `__tests__/`-nested files for Cypress**: Cypress convention is `cypress/e2e/`.
- **k6 files often have no suffix pattern**: they're `.js` files identified only by imports. Do not
  glob-match all `.js` files as k6 tests.

## Env var extraction

Language-specific patterns to scan test files for. Report unique names, no values. Sort output.

| Language | Pattern | Notes |
|---|---|---|
| JS/TS | `process\.env\.(\w+)` | Node.js |
| JS/TS | `import\.meta\.env\.(\w+)` | Vite |
| JS/TS (k6) | `__ENV\.(\w+)` | k6 script env |
| JS/TS (Cypress) | `Cypress\.env\(['"](\w+)['"]\)` | Cypress env plugin |
| Go | `os\.Getenv\(['"](\w+)['"]\)` | stdlib |
| Java | `System\.getenv\(['"](\w+)['"]\)` | stdlib |
| Python | `os\.environ\[['"](\w+)['"]\]`, `os\.environ\.get\(['"](\w+)['"]\)`, `os\.getenv\(['"](\w+)['"]\)` | stdlib |
| Ruby | `ENV\[['"](\w+)['"]\]` | stdlib |
| Rust | `env::var\(['"](\w+)['"]\)` | std::env |

Cap at 20 env vars per suite. If more are found, take the first 20 alphabetically and add a warning.

## Content sniff false positives

The k6 and Puppeteer detectors use content sniffing on `.js`/`.ts` files. These are prone to false positives.

### Rules of thumb

- **Match imports at the top of the file** (first 100 lines), not throughout. Test files typically import
  their runner in the first 10 lines.
- **Require quoted string in the import**: `from 'k6'` or `from "k6"`, not `from k6` (naked identifier).
- **Distinguish `from 'k6'` vs `from 'k6.5'`**: word boundary. Use `\b` in regex.
- **Ignore files inside `node_modules/`, `dist/`, `build/`, `vendor/`**.

### Confidence adjustment for content sniff

Content-sniffed suites start at 0.65 confidence. Bump to 0.75 if:
- The file lives in a directory named `load/`, `perf/`, `benchmarks/`, `k6/` (organizational signal)
- Multiple `.js` files in the same dir all sniff to k6

## When the repo has no `package.json` but has `.js` test files

Rare. Vanilla-JS or Deno projects. Approach:
- Look for `deno.json` / `deno.jsonc` → Deno test runner
- Look for `bun.lock` / `bunfig.toml` → Bun test runner
- Look for browser-side tests (Karma, TAP-style) — very uncommon, emit `unknown` framework with evidence

## Language detection when marker files conflict

A repo can have `package.json` for tooling (linting, formatting) but no JS/TS source or tests. Signal for
"real" JS project:
- `src/` or `lib/` with `.js`/`.ts` files
- More than one JS/TS file outside `scripts/`, `tools/`

If `package.json` exists but there are no `.js`/`.ts` files outside tooling dirs, do NOT emit JS as a language.
