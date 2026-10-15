# Working with Testkube Skills (testkube-skills)

## Purpose

- The public source of the Testkube agent skills, in the [Agent Skills](https://agentskills.io) format, published as one plugin, `testkube-skills`, for Claude Code, Codex and Cursor.
- Users install these skills into their own agents, so a skill change ships to customers. Treat a `SKILL.md` like product code.

## Layout

- `plugins/testkube-skills/skills/<name>/` holds one skill:
  - `SKILL.md`, with `name` and `description` frontmatter. The `name` must match the folder name. The `description` is what an agent matches a request against, so it states when to use the skill and what it does not do.
  - `agents/openai.yaml`, the Codex display metadata (`display_name`, `short_description`, `default_prompt`). Every skill needs one.
  - Optional `references/` (loaded on demand), `assets/` (schemas and templates) and `examples/`.
- The skills are `testkube` (orientation and routing), `installing-testkube-cli`, `installing-testkube-oss-agent`, `test-discovery`, `testworkflow-author` and `testworkflow-runner`. `README.md` describes each one and how they chain.
- Plugin manifests:
  - Per plugin: `plugins/testkube-skills/.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` and `.cursor-plugin/plugin.json`. The Codex one also carries the `interface` block and the icons in `plugins/testkube-skills/assets/`.
  - Marketplaces at the repository root: `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json` (Codex) and `.cursor-plugin/marketplace.json`.
- `tests/` holds the checks described under "Verifying a change".

## Adding or changing a skill

- Adding, removing or renaming a skill: update `README.md` (its section, the diagram, the copy commands and the `/testkube-skills:<name>` list), and the plugin descriptions and Codex `longDescription` that count or name the skills.
- Changing what a skill does: keep its `description` and its README section in step.
- Keep the version the same in the three `plugin.json` files and in the Claude and Cursor `marketplace.json` files, and bump it in all five for a release.
- The `testkube` skill keeps a curated index of `docs.testkube.io` URLs. Add a URL only after checking that it resolves to a canonical page, not to a redirect stub (see the comment in `tests/docs-index/run.sh`).
- A skill runs inside someone else's agent, on their machine. It does not install anything or change a cluster without asking first, and it does not invent credentials. Keep to the pattern the setup skills follow: find what exists and reuse it, then confirm each step before acting.

## Verifying a change

```bash
bash tests/docs-index/run.sh                   # after editing the docs index in the testkube skill
tests/testworkflow-author-json-mode/run.sh     # after editing testworkflow-author or test-discovery
```

- `docs-index` runs in CI (`.github/workflows/docs-index.yml`) on pull requests that touch the `testkube` skill, and every Monday. It needs network access.
- The JSON-mode tests need `bash` and `python3`; they use `jsonschema` and the `testkube` CLI when present. They are not in CI, so run them yourself.
- Nothing checks the other skills automatically. Read the changed `SKILL.md` as the agent will see it, and try the skill in an agent on a task its `description` claims.

## Other places that carry these skills

- `kubeshop/testkube-cloud-api` carries `testworkflow-author`, `testworkflow-runner` and `test-discovery` in `js/packages/runspace-controller/skills/`, adapted to the runspace's tools (editing a workflow through `edit_workflow` instead of writing YAML). The files they share with this repository, mostly the schemas, examples and references, are listed in its `shared-skills.txt` with a pinned commit of this repository, and its `cloud-skills-drift` check fails when a copy differs. A change here reaches the runspace only when someone moves that pin and syncs the copies there; the adapted `SKILL.md` files are not copies and stay separate.
- `kubeshop/testkube-docs` links to the docs index: its `AGENTS.md` asks for a fix here when a docs slug is renamed.

## PR title format

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `chore:` and so on, for example `fix: verify the Helm repository URL before reusing it`.
