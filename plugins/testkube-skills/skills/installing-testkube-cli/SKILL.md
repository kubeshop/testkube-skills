---
name: installing-testkube-cli
description: "Install, upgrade, or verify the Testkube CLI (the `testkube` / `tk` / `kubectl-testkube` command) on Linux, macOS, or Windows. Use when the CLI is missing (`testkube: command not found`), before running any Testkube skill that shells out to `testkube`, or when a specific CLI version is required. Checks for an existing installation first and reuses it when present, and installs only through a package manager after confirming with the user — never reinstalls a working CLI."
---

# installing-testkube-cli

Ensure the Testkube CLI is available before other Testkube skills use it. The CLI ships as a single binary named
`kubectl-testkube` with two convenience symlinks, `testkube` and `tk` — installing any one gives you all three.

**Always check for an existing installation first and reuse it.** Only install when the CLI is absent, or when a
specific version is required and the installed one differs. Reinstalling a working CLI is wasteful and can clobber a
version the environment depends on.

## The Core Loop

1. **Check for an existing CLI** — this comes before any install step:

   **Linux/macOS (bash/zsh):**
   ```bash
    TK_CMD="$(command -v testkube 2>/dev/null || command -v tk 2>/dev/null || command -v kubectl-testkube 2>/dev/null)"
    if [ -n "$TK_CMD" ]; then echo "$TK_CMD"; else echo "Testkube CLI not found"; fi
   ```

   **Windows (PowerShell):**
   ```powershell
   $TK_CMD = (Get-Command testkube, tk, kubectl-testkube -ErrorAction SilentlyContinue | Select-Object -First 1).Source
   $TK_CMD
   ```

   If any path is printed, the CLI is already installed. Confirm it runs:

   **Linux/macOS (bash/zsh):**
   ```bash
   if [ -n "$TK_CMD" ]; then "$TK_CMD" version; else echo "Testkube CLI not found"; fi
   ```

   **Windows (PowerShell):**
   ```powershell
   if ($TK_CMD) { & $TK_CMD version } else { Write-Host "Testkube CLI not found" }
   ```
   If no specific version was requested, **stop here and reuse the existing binary**. If a specific version was
   requested, compare the client version from `testkube version` to the target — reuse when they match; install or
   upgrade only when they differ.
2. **Only if absent or wrong version, install through a package manager — after confirming with the user** — pick the
   method for the platform (see Install), make sure its package manager is on PATH, describe the exact command and
   version, wait for the user's go-ahead, and run it. When no supported package manager is available, **do not
   download the CLI yourself** — hand off to the user (see [No package manager](#no-package-manager)).
3. **Verify** — confirm the client version prints:

   **Linux/macOS (bash/zsh):**
   ```bash
   TK_CMD="$(command -v testkube || command -v tk || command -v kubectl-testkube)"
   if [ -n "$TK_CMD" ]; then "$TK_CMD" version; else echo "Testkube CLI not found"; fi
   ```

   **Windows (PowerShell):**
   ```powershell
   $TK_CMD = (Get-Command testkube, tk, kubectl-testkube -ErrorAction SilentlyContinue | Select-Object -First 1).Source
   if ($TK_CMD) { & $TK_CMD version } else { Write-Host "Testkube CLI not found" }
   ```
4. **Report** — state whether an existing CLI was reused or a new one installed, and the resulting version.

## Rules

1. **MUST check for an existing CLI before installing.** Run `command -v testkube` (or `tk` / `kubectl-testkube`)
   first. If it resolves, reuse it — do not reinstall.
2. **MUST confirm with the user before installing or upgrading.** Describe the exact install command (and version)
   and wait for the user's go-ahead before running it — never install unprompted.
3. **MUST install only through a package manager.** Use Homebrew, APT, or Chocolatey as listed under Install. Never
   download and run an install script, and never download a release binary or tarball — not even a pinned one. If
   none of those package managers is available, stop and hand off to the user.
4. **MUST pin an exact version with APT and Chocolatey.** Pass the version explicitly (`testkube=<version>`,
   `--version <version>`); look it up first if the user did not name one.
5. **MUST NOT reinstall a working CLI.** Install only when the CLI is absent, or when a required version differs from
   the one reported by `testkube version`.
6. **MUST verify after installing.** `testkube version` must print a client version before reporting success.
7. **MUST NOT install the cluster agent here.** This skill installs only the client binary. Deploying the Testkube
   agent/control plane into a cluster is separate (`testkube init standalone-agent`, Helm). See
   https://docs.testkube.io/articles/install/overview.

## Prerequisites

The installed client binary has no runtime dependencies; the install method needs its package manager on PATH.

| Method | Requires on PATH |
|--------|------------------|
| macOS / Linux (Homebrew) | `brew` |
| Ubuntu / Debian (APT) | `sudo`, `apt-get`, `gnupg`, `wget` |
| Windows (Chocolatey) | `choco` |

```bash
command -v brew || command -v apt-get || echo "no supported package manager; see 'No package manager'"
```

## Install

Only reached when step 1 finds no existing CLI, or when a required version differs from the installed one.

| Platform | Command |
|----------|---------|
| macOS / Linux (Homebrew) | `brew install testkube` |
| Ubuntu / Debian (APT) | `sudo apt-get install -y --allow-downgrades testkube=<version>` after adding the repository — see [Ubuntu / Debian](#ubuntu--debian-apt) |
| Windows (Chocolatey) | `choco install testkube --version <version> -y` after adding the source — see [Windows](#windows-chocolatey) |
| Anything else | [No package manager](#no-package-manager) — the user installs it |

Testkube versions are the bare number with **no `v` prefix** (`2.14.1`, not `v2.14.1`); the list of releases is at
https://github.com/kubeshop/testkube/releases.

### Homebrew

```bash
brew install testkube      # upgrade later with: brew upgrade testkube
```

Homebrew installs the current release of the formula and cannot pin an older one. When the user needs a specific
version that differs from what `brew info testkube` offers, use APT or Chocolatey, or hand off to the user.

### Ubuntu / Debian (APT)

Add the Testkube repository once:

```bash
sudo apt-get update && sudo apt-get install -y gnupg wget
sudo install -m 0755 -d /etc/apt/keyrings
wget -qO- https://repo.testkube.io/key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/testkube.gpg
echo "deb [signed-by=/etc/apt/keyrings/testkube.gpg] https://repo.testkube.io/linux linux main" | sudo tee /etc/apt/sources.list.d/testkube.list
sudo apt-get update
```

Then list the available versions and install an exact one:

```bash
apt-cache madison testkube                       # pick a version from this list
sudo apt-get install -y --allow-downgrades testkube=<version>   # e.g. testkube=2.14.1
```

### Windows (Chocolatey)

```powershell
choco source add --name=kubeshop_repo --source=https://chocolatey.kubeshop.io/chocolate
choco search testkube --exact --all-versions     # pick a version from this list
choco install testkube --version <version> -y    # e.g. --version 2.14.1
```

### No package manager

When none of Homebrew, APT, or Chocolatey is available (another Linux distribution, an air-gapped machine, no `sudo`
in a non-interactive shell), **stop and ask the user to install the CLI themselves** — do not download a script,
tarball, or binary on their behalf. Point them to the install guide:

https://docs.testkube.io/articles/install/cli

Once they confirm it is installed, resume at step 3 (Verify).

## Upgrade / reinstall

Confirm with the user first (Rule 2) — describe the exact command and target version:

- Homebrew: `brew upgrade testkube`
- APT: `sudo apt-get update && sudo apt-get install -y --allow-downgrades testkube=<version>` (upgrades or downgrades)
- Chocolatey: `choco upgrade testkube --version <version> -y` (add `--allow-downgrade` to go back a version)

## Common Mistakes

- **Reinstalling when the CLI is already present** — always run the step-1 existence check first and reuse what's there.
- **Downloading the CLI when no package manager fits** — hand off to the user with the install guide instead
  (Rule 3).
- **`testkube: command not found` after install** — the package manager's bin directory isn't on PATH, or the shell
  cached the old lookup. Run `hash -r` (bash/zsh) or open a new shell, then `which testkube`.
- **`sudo: a terminal is required to read the password`** — APT needs `sudo`, which can't prompt in a non-interactive
  shell (CI/agent). Ask the user to run the install themselves, or use Homebrew, which doesn't need root.
- **`E: Packages were downgraded and -y was used without --allow-downgrades`** — the requested version is older than
  the installed one. Add `--allow-downgrades`, as the commands above do.
- **`E: Version '<version>' for 'testkube' was not found`** — the version has a `v` prefix or isn't published. Pick an
  exact version from `apt-cache madison testkube`.
- **Chocolatey can't find the package** — add the source first:
  `choco source add --name=kubeshop_repo --source=https://chocolatey.kubeshop.io/chocolate`.
- **Confusing CLI with cluster install** — this skill installs only the client binary; the cluster agent is separate.
