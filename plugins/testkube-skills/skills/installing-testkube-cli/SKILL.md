---
name: installing-testkube-cli
description: >
  Install, upgrade, or verify the Testkube CLI (the `testkube` / `tk` / `kubectl-testkube` command) on Linux, macOS, or
  Windows. Use when the CLI is missing (`testkube: command not found`), before running any Testkube skill that shells
  out to `testkube`, or when a specific CLI version is required. Checks for an existing installation first and reuses it
  when present, and installs only after confirming with the user — never reinstalls a working CLI.
metadata:
  initiative: test-authoring
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
2. **Only if absent or wrong version, install — after confirming with the user** — first make sure the chosen method's
   prerequisites are on PATH (see Prerequisites), then describe the exact install command, wait for the user's
   go-ahead, and run it (see Install). Recommended on Linux/macOS:
   ```bash
   curl -sSLf https://get.testkube.io -o /tmp/testkube-install.sh && bash /tmp/testkube-install.sh
   ```
   Run it with **`bash`**, not `sh` — the script uses `set -eo pipefail`, which fails under `dash`
   (the default `/bin/sh` on Debian/Ubuntu) with `Illegal option -o pipefail`.
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
   first. If it resolves, reuse it — do not download or reinstall.
2. **MUST confirm with the user before installing or upgrading.** Describe the exact install command (and version)
   and wait for the user's go-ahead before running it — never install unprompted.
3. **MUST NOT reinstall a working CLI.** Install only when the CLI is absent, or when a required version differs from
   the one reported by `testkube version`.
4. **MUST verify after installing.** `testkube version` must print a client version before reporting success.
5. **MUST NOT install the cluster agent here.** This skill installs only the client binary. Deploying the Testkube
   agent/control plane into a cluster is separate (`testkube init standalone-agent`, Helm). See
   https://docs.testkube.io/articles/install/overview.

## Prerequisites

The installed client binary has no runtime dependencies, but each install *method* needs a few tools on PATH. Check
them before installing; if any are missing, install them with the OS package manager first (confirm with the user, per
Rule 2).

| Method | Requires on PATH |
|--------|------------------|
| Install script (recommended) | `curl` and `jq` — the script exits early if either is missing |
| Manual download | `curl` or `wget`, plus `tar` |
| Ubuntu / Debian (APT) | `sudo`, `apt-get`, `gnupg`, `wget` |
| macOS (Homebrew) | `brew` |
| Windows (Chocolatey) | `choco` |

Quick check for the recommended script method:

```bash
command -v curl && command -v jq || echo "install curl and/or jq first (e.g. sudo apt-get install -y curl jq)"
```

## Install

Only reached when step 1 finds no existing CLI, or when a required version differs from the installed one.

| Platform | Command |
|----------|---------|
| Linux / macOS (script) | `curl -sSLf https://get.testkube.io -o /tmp/testkube-install.sh && bash /tmp/testkube-install.sh` |
| macOS (Homebrew) | `brew install testkube` |
| Ubuntu / Debian (APT) | see [Ubuntu / Debian](#ubuntu--debian-apt) below |
| Windows (Chocolatey) | `choco install testkube -y` (after adding the source) |
| Specific version | Use the export flow in [Install script (recommended)](#install-script-recommended): export `TESTKUBE_VERSION=<version>`, then run the installer |
| Beta channel | `curl -sSLf https://get.testkube.io \| bash -s -- beta` |

### Install script (recommended)

The script auto-detects OS (Linux/Darwin) and arch (x86_64/arm64/i386), downloads the matching release tarball
from GitHub, and installs into `/usr/local/bin` (using `sudo` only if that directory isn't writable). For Windows,
use the Chocolatey method below or install manually.

 ```bash
 curl -sSLf https://get.testkube.io -o /tmp/testkube-install.sh && bash /tmp/testkube-install.sh
 ```

Pin a version by exporting `TESTKUBE_VERSION` first (pick a release from
https://github.com/kubeshop/testkube/releases):

 ```bash
 export TESTKUBE_VERSION=<version>
 curl -sSLf https://get.testkube.io -o /tmp/testkube-install.sh && bash /tmp/testkube-install.sh
 ```

### No-sudo / non-interactive install

The script installs into `/usr/local/bin`, which usually needs `sudo`. In a non-interactive session
(CI, an agent shell, no TTY) `sudo` can't prompt for a password and the script fails with
`sudo: a terminal is required to read the password`. When you can't use `sudo` interactively, install
the binary into a writable directory that's already on PATH (e.g. `~/.local/bin`) — no root needed:

> **Release tags have NO `v` prefix.** The tag and the version in the filename are the bare number,
> e.g. `2.11.0` — the download path is `releases/download/2.11.0/testkube_2.11.0_...`, NOT
> `releases/download/v2.11.0/...`. A `v`-prefixed URL 404s. Set `VER` to the bare number (no `v`).

```bash
VER="${TESTKUBE_VERSION:-2.11.0}"   # bare version, NO 'v' prefix; releases at github.com/kubeshop/testkube/releases
TARBALL="testkube_${VER}_Linux_x86_64.tar.gz"
curl -sSLf "https://github.com/kubeshop/testkube/releases/download/${VER}/${TARBALL}" -o "/tmp/${TARBALL}"
tar -xzf "/tmp/${TARBALL}" -C /tmp kubectl-testkube
mkdir -p "$HOME/.local/bin"
install -m 0755 /tmp/kubectl-testkube "$HOME/.local/bin/kubectl-testkube"
ln -sf "$HOME/.local/bin/kubectl-testkube" "$HOME/.local/bin/testkube"
ln -sf "$HOME/.local/bin/kubectl-testkube" "$HOME/.local/bin/tk"
```

Confirm `~/.local/bin` is on PATH (`echo "$PATH" | tr ':' '\n' | grep -F "$HOME/.local/bin"`); if not,
pick another writable PATH dir. Swap `Linux_x86_64` for your OS/arch (`Darwin_arm64`, etc.).

### Homebrew

```bash
brew install testkube      # upgrade later with: brew upgrade testkube
```

### Ubuntu / Debian (APT)

```bash
sudo apt-get update && sudo apt-get install -y gnupg wget
sudo install -m 0755 -d /etc/apt/keyrings
wget -qO- https://repo.testkube.io/key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/testkube.gpg
echo "deb [signed-by=/etc/apt/keyrings/testkube.gpg] https://repo.testkube.io/linux linux main" | sudo tee /etc/apt/sources.list.d/testkube.list
sudo apt-get update
sudo apt-get install -y testkube
```

### Windows (Chocolatey)

```powershell
choco source add --name=kubeshop_repo --source=https://chocolatey.kubeshop.io/chocolate
choco install testkube -y
```

### Manual

When you can't run the script (air-gapped, custom install dir, CI without curl-pipe):

1. Download the tarball for your OS/arch from https://github.com/kubeshop/testkube/releases — file name is
   `testkube_<version>_<OS>_<arch>.tar.gz` (e.g. `testkube_2.11.0_Linux_x86_64.tar.gz`). The tag and
   `<version>` are the bare number with **no `v` prefix** (`2.11.0`, not `v2.11.0`) — a `v`-prefixed URL 404s.
2. Extract `kubectl-testkube` and move it onto PATH:

```bash
tar -xzf testkube_<version>_<OS>_<arch>.tar.gz kubectl-testkube
sudo mv kubectl-testkube /usr/local/bin/kubectl-testkube
sudo ln -sf /usr/local/bin/kubectl-testkube /usr/local/bin/testkube
sudo ln -sf /usr/local/bin/kubectl-testkube /usr/local/bin/tk
```

## Upgrade / reinstall

Confirm with the user first (Rule 2) — describe the exact command and target version, then re-run the same install
command. The script and Homebrew both overwrite the existing binary with the chosen release. To downgrade, pin
`TESTKUBE_VERSION` (script) or use a manual download.

## Common Mistakes

- **Reinstalling when the CLI is already present** — always run the step-1 existence check first and reuse what's there.
- **`testkube: command not found` after install** — `/usr/local/bin` isn't on PATH, or the shell cached the old lookup.
  Run `hash -r` (bash/zsh) or open a new shell, then `which testkube`.
- **Script aborts immediately** — missing `curl` or `jq`. Install them via your package manager first.
- **`Illegal option -o pipefail`** — you ran the script with `sh`/`dash`. It requires `bash` (`set -eo pipefail`).
  Re-run with `bash /tmp/testkube-install.sh`.
- **`sudo: a terminal is required to read the password`** — the script needs `sudo` for `/usr/local/bin` but there's
  no interactive TTY (CI/agent shell). Use the [No-sudo / non-interactive install](#no-sudo--non-interactive-install)
  into a writable PATH dir like `~/.local/bin`.
- **`curl: (22) ... 404` on the release download** — you added a `v` to the version. Testkube release tags have **no
  `v` prefix**: the URL is `releases/download/2.11.0/testkube_2.11.0_...`, not `.../v2.11.0/...`. Use the bare number.
- **Chocolatey can't find the package** — add the source first:
  `choco source add --name=kubeshop_repo --source=https://chocolatey.kubeshop.io/chocolate`.
- **Confusing CLI with cluster install** — this skill installs only the client binary; the cluster agent is separate.
