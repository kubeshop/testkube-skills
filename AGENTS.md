# Working with Testkube Skills (testkube-skills)

The public source of the Testkube agent skills, in the [Agent Skills](https://agentskills.io) format, published as one plugin, `testkube-skills`, for Claude Code, Codex and Cursor.

Owner: `@kubeshop/testkube-backend`, the team that owns testkube-cloud-api. This repository has no CODEOWNERS file, so nothing assigns reviewers automatically.

The seven sections below are: verifying a change, reproducing a bug, the repository map, the conventions reviewers enforce, what never to do, the pull request checks, and the skills and how to try them.

## 1. Verifying a change

Users install these skills into their own agents, so a skill change ships to customers. Treat a `SKILL.md` like product code.

```bash
bash tests/skill-frontmatter/run.sh            # after editing any skill: name, description, agents/openai.yaml
bash tests/docs-index/run.sh                   # after editing the docs index in the testkube skill
tests/testworkflow-author-json-mode/run.sh     # after editing testworkflow-author or test-discovery
```

- `docs-index` checks every `docs.testkube.io` URL the `testkube` skill cites. It needs network access. It fails on a 404 and on a redirect stub, and only warns when a page is missing from the sitemap. In CI it took 12 to 24 seconds over the 13 runs between August and October 2026 (GitHub API, run start to last update).
- The JSON-mode tests need `bash` and `python3`; they use `jsonschema` and the `testkube` CLI when present. They need no network and no secrets. They are not in CI, so run them yourself. The `testkube --dry-run` step is advisory: it needs a reachable Testkube context, and a failure there is not a YAML defect.
- `skill-frontmatter` checks every skill's `name` against its directory and the Agent Skills rules, keeps `description` within the 1024-character limit, and checks that `agents/openai.yaml` invokes the skill by name. It needs only `bash` and `python3`, and runs in CI. The `testkube` skill's description is already near the limit.
- Beyond the frontmatter, nothing checks a skill's instructions. Read the changed `SKILL.md` as the agent will see it, and try the skill in an agent on a task its `description` claims (section 7).

## 2. Reproducing a bug

A skill bug is an agent doing the wrong thing with the skill loaded.

- **Load your checkout, not the published plugin.** Copy the skill folder from `plugins/testkube-skills/skills/<name>` into the agent's skills folder (section 7), then invoke it with `/<name>` and the request that misbehaved. Keep the request on the task its `description` claims, since the `description` is what the agent matches against.
- **JSON mode of `testworkflow-author`:** `tests/testworkflow-author-json-mode/` holds the fixtures. `input.example.json` is an authoring request; `output.example.json` and `output.needs-input.example.json` are the `success` and `needs_input` envelopes; `compose.discovery-input.json` is a four-suite `test-discovery` manifest and `compose.output.example.json` the orchestrator built from it. Its `README.md` lists the five checks. Add a fixture or a check that fails, then fix the skill.
- **A broken docs link in the `testkube` skill:** `bash tests/docs-index/run.sh` names the URL, and for a redirect stub it prints the target to replace it with.
- **`test-discovery` output:** `plugins/testkube-skills/skills/test-discovery/examples/` holds sample manifests (an empty repository, a single Playwright suite, a polyglot monorepo, an ambiguous `needs_input` case). Compare a bad manifest with them and with `assets/manifest-schema.json`.

## 3. Repository map

Nothing in this repository is generated; every file is edited by hand.

- `plugins/testkube-skills/skills/<name>/` holds one skill:
  - `SKILL.md`, with `name` and `description` frontmatter.
  - `agents/openai.yaml`, the Codex display metadata (`display_name`, `short_description`, `default_prompt`).
  - Optional `references/` (loaded on demand), `assets/` (schemas and templates) and `examples/`.
- Plugin manifests:
  - Per plugin: `plugins/testkube-skills/.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and `.cursor-plugin/plugin.json`. The Codex one also carries the `interface` block and the icons in `plugins/testkube-skills/assets/`.
  - Marketplaces at the repository root: `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json` (Codex) and `.cursor-plugin/marketplace.json`.
- `tests/skill-frontmatter/run.sh` checks every skill's frontmatter; `tests/docs-index/run.sh` checks the docs index; `tests/testworkflow-author-json-mode/` holds the JSON-mode contract tests and their fixtures.
- `.github/workflows/skill-frontmatter.yml` and `.github/workflows/docs-index.yml` are the two workflows (section 6).
- `README.md` is the user-facing description of every skill. `CLAUDE.md` points at this file.

### Other places that carry these skills

- `kubeshop/testkube-cloud-api` carries `testworkflow-author`, `testworkflow-runner` and `test-discovery` in `js/packages/runspace-controller/skills/`, adapted to the runspace's tools (editing a workflow through `edit_workflow` instead of writing YAML). The files they share with this repository, mostly the schemas, examples and references, are listed in its `shared-skills.txt` with a pinned commit of this repository, and its `cloud-skills-drift` check fails when a copy differs. A change here reaches the runspace only when someone moves that pin and syncs the copies there; the adapted `SKILL.md` files are not copies and stay separate.
- `kubeshop/testkube-docs` links to the docs index: its `AGENTS.md` asks for a fix here when a docs slug is renamed.

## 4. Conventions reviewers enforce

### Frontmatter and metadata

- The `name` must match the folder name.
- The `description` is what an agent matches a request against, so it states when to use the skill and what it does not do.
- Every skill needs an `agents/openai.yaml`.

### Keeping the files in step

- Adding, removing or renaming a skill: update `README.md` (its section, the diagram, the copy commands and the `/testkube-skills:<name>` list), and the plugin descriptions and Codex `longDescription` that count or name the skills.
- Changing what a skill does: keep its `description` and its README section in step.
- Keep the version the same in the three `plugin.json` files and in the Claude and Cursor `marketplace.json` files, and bump it in all five for a release. The Codex marketplace carries no version.
- The `testkube` skill keeps a curated index of `docs.testkube.io` URLs. Add a URL only after checking that it resolves to a canonical page, not to a redirect stub (see the comment in `tests/docs-index/run.sh`).

### Pull requests

Titles use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:` and so on, for example `fix: verify the Helm repository URL before reusing it`. No check enforces it.

## 5. Never do these

- **Do not write a skill that installs anything or changes a cluster without asking first, or that invents credentials.** A skill runs inside someone else's agent, on their machine. Keep to the pattern the setup skills follow: find what exists and reuse it, then confirm each step before acting.
- **Do not change the version in one manifest only.** The three `plugin.json` files and the Claude and Cursor marketplaces move together.
- **Do not fix a shared file in the runspace copy in `testkube-cloud-api`.** Change it here; the copy there follows the pinned commit, and its `cloud-skills-drift` check fails when the two differ.
- **Do not add a docs URL that redirects.** `docs-index` fails on it, and a failed Monday run opens an issue.

## 6. Pull request checks and the MCP tools

There are no Testkube quality-loop workflows for this repository, so no Testkube MCP steps apply. There are two GitHub Actions.

`.github/workflows/skill-frontmatter.yml` runs `bash tests/skill-frontmatter/run.sh` on pull requests and pushes to `main` that touch any skill, the check or the workflow, and by hand (`workflow_dispatch`).

`.github/workflows/docs-index.yml`:

- It runs `bash tests/docs-index/run.sh` on pull requests and pushes to `main` that touch `plugins/testkube-skills/skills/testkube/SKILL.md`, `tests/docs-index/` or the workflow itself, every Monday at 06:00 UTC, and by hand (`workflow_dispatch`).
- A failed Monday run opens an issue, or comments on the open one, instead of failing into a log nobody reads.
- It took 12 to 24 seconds per run (section 1).

GitHub Copilot code review also runs on pull requests. It is not a file in `.github/workflows`; its seven runs on 8 October 2026 took 105 to 185 seconds each (GitHub API, run start to last update).

## 7. Skills and starting a component

### The skills

| Skill | Does |
| --- | --- |
| `testkube` | Orientation and routing: explains Testkube, indexes the docs, routes to the others. Installs and runs nothing. |
| `installing-testkube-cli` | Installs, upgrades or verifies the `testkube` CLI, reusing a working one. |
| `installing-testkube-oss-agent` | Sets up a local OSS standalone agent (k3d by default), reusing an existing one. |
| `test-discovery` | Walks a cloned repository and reports its tests as a JSON manifest or a Markdown report. Runs nothing. |
| `testworkflow-author` | Writes and validates TestWorkflow YAML, with an optional JSON mode. |
| `testworkflow-runner` | Runs TestWorkflows, reads logs and diagnoses failures. Does not edit YAML. |

`README.md` describes each one and how they chain: `testkube` routes, the two setup skills get a CLI and an environment ready, and the core chain runs discover, author, run.

### Trying a skill locally

There is no service to start. Load the skills into an agent, as `README.md` describes:

- **Claude Code:** `cp -r plugins/testkube-skills/skills/<name> ~/.claude/skills/`, then `/<name> <request>`. The published plugin installs with `/plugin marketplace add kubeshop/testkube-skills` and `/plugin install testkube-skills@testkube-skills`, and its skills are `/testkube-skills:<name>`; that installs what is published, not your branch.
- **VS Code / GitHub Copilot:** copy the folder into `.github/skills/`.
- **Codex:** from a clone, enable the plugin with the `/plugins` UI. Codex reads `.agents/plugins/marketplace.json` and `plugins/testkube-skills/.codex-plugin/plugin.json`, and caches plugins under `~/.codex/plugins/cache/testkube-skills/testkube-skills/local/`.
- **Cursor:** point Cursor at this repository's marketplace, `.cursor-plugin/marketplace.json`.

The skills that shell out need the Testkube CLI and, to run anything, a Testkube environment; `installing-testkube-cli` and `installing-testkube-oss-agent` provide both.
