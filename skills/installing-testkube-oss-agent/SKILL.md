---
name: installing-testkube-oss-agent
description: >
  Set up a local Testkube OSS standalone agent — deploy the open-source Testkube agent into a Kubernetes cluster for
  local testing (k3d by default when a fresh local cluster is needed; minikube, kind, k3d, or remote all work). Use when
  you need a local OSS Testkube environment and none is running yet. Checks for an existing Testkube agent in the
  current cluster of ANY type first and reuses it; installs missing pieces only after confirming each step with the
  user.
metadata:
  initiative: test-authoring
---

# installing-testkube-oss-agent

Set up a self-contained local Testkube OSS install: a Kubernetes cluster with the **Testkube standalone agent**
deployed into its `testkube` namespace. Standalone (OSS) mode has **no web dashboard** — everything is driven through
the CLI. **k3d** (k3s in Docker) is the default when you need a *fresh* local cluster, but any cluster works.

**Always check for an existing Testkube agent first — in the current cluster of any type (minikube, kind, k3d,
remote) — and reuse it.** Only create a cluster or deploy the agent when none is running, and **confirm each mutating
step with the user before running it** — these commands install binaries, create clusters, and deploy into them.

## The Core Loop

Run these in order. Reuse whatever already exists; confirm every mutating step with the user before running it.

1. **Check prerequisites** — install any missing ones with the OS package manager first (confirm with the user, per
   Rule 2).

   Always required:
   ```bash
    TK_CMD="$(command -v testkube 2>/dev/null || command -v tk 2>/dev/null || command -v kubectl-testkube 2>/dev/null)"  # Testkube CLI — else use installing-testkube-cli
    if [ -n "$TK_CMD" ]; then echo "$TK_CMD"; else echo "Testkube CLI not found; use installing-testkube-cli"; fi
   command -v kubectl                                  # kubectl — talk to the cluster
   command -v helm                                     # helm — testkube init standalone-agent invokes Helm internally
   command -v curl                                     # curl — k3d install script
   ```

   Only when you need a fresh local k3d cluster (steps 3–4):
   ```bash
   docker info >/dev/null 2>&1 && echo docker-ok       # Docker daemon must be running
   ```

   Required always: the **Testkube CLI**, **`kubectl`**, **`helm`**, and **`curl`**. **Docker** is required only when
   creating a k3d cluster. `k3d` itself is installed in step 3 if it's missing and you need a fresh local cluster.
2. **Check for an existing Testkube agent — in the current cluster of ANY type — and reuse it.** The agent may
   already be running in minikube, kind, k3d, or a remote cluster; detection is cluster-agnostic. Before creating
   anything:
   ```bash
   TK_CMD="$(command -v testkube || command -v tk || command -v kubectl-testkube)"
   kubectl config current-context      # which cluster are we pointed at?
    if kubectl get namespace testkube >/dev/null 2>&1; then kubectl get pods -n testkube; else echo "testkube namespace not found"; fi   # is a Testkube agent Running here?
   if [ -n "$TK_CMD" ]; then "$TK_CMD" version; else echo "Testkube CLI not found; use installing-testkube-cli"; fi  # does it print a SERVER version too?
   ```
   If the `testkube` namespace has Running agent pods and `testkube version` shows a server version, it is already
   installed — **stop here and use it**, whatever the cluster type. If the agent runs in a different cluster, list
   contexts and switch to it rather than creating a new one:
   ```bash
   kubectl config get-contexts
   kubectl config use-context <context-with-the-agent>   # e.g. minikube, kind-..., k3d-testkube
   ```
   Steps 3–4 create a *fresh local* cluster with k3d — **skip both entirely if you already have a usable cluster**
   (minikube, kind, k3d, remote) and just deploy the agent into it (step 5).
3. **Install k3d (if missing)** — confirm with the user, then:
   ```bash
   command -v bash
   curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/v5.7.4/install.sh -o /tmp/k3d-install.sh
   TAG=v5.7.4 bash /tmp/k3d-install.sh
   ```
   Skip if `command -v k3d` already resolves, or if you're reusing minikube/kind/another cluster (e.g. `brew install k3d`).
4. **Create the cluster (if missing)** — confirm, then:
   ```bash
   k3d cluster create testkube
   ```
   Skip if you already have a running cluster to use — reuse it (e.g. `minikube start` / an existing `k3d cluster
   list` entry). k3d merges its context into your kubeconfig and switches to it.
5. **Deploy the agent (if missing)** — confirm, then:
   ```bash
   TK_CMD="$(command -v testkube || command -v tk || command -v kubectl-testkube)"
   if [ -n "$TK_CMD" ]; then "$TK_CMD" init standalone-agent --no-confirm; else echo "Testkube CLI not found; use installing-testkube-cli"; fi
   ```
   (`testkube init oss` is an alias.) Skip if the `testkube` namespace already has the agent Running. **Get the
   user's approval before running this (Rule 2).** Note: `testkube init standalone-agent` prints
   `Do you want to continue? [Y/n]` and reads the answer from the terminal (`/dev/tty`) — piping `yes` or any answer
   to stdin does **not** reach it, so in a non-interactive / agent / CI shell the command hangs forever. Once the user
   has approved out of band, run it non-interactively: prefer the **Helm alternative below** (inherently
   non-interactive), or pass `--no-confirm` (the human approval Rule 2 requires has already happened — see Rule 6).
   Only when a real human is at the terminal should you leave the prompt for them to answer.
6. **Verify** — wait until the API server pods are `Running` (and MinIO if installed — it is by default), then confirm
   CLI ↔ server:
   ```bash
   TK_CMD="$(command -v testkube || command -v tk || command -v kubectl-testkube)"
   kubectl get all -n testkube
   if [ -n "$TK_CMD" ]; then "$TK_CMD" version; else echo "Testkube CLI not found; use installing-testkube-cli"; fi  # must print client AND server versions
   ```
   The `testkube-api-server` pod often shows several restarts in the first ~2 minutes while it waits for MongoDB
   or PostgreSQL, MinIO, and NATS to become ready — this is normal startup behavior, not a failure. Wait for `Ready 1/1`, 
   not for zero restarts.
7. **Report** — state what was reused vs newly installed, and the cluster/context name.

## Rules

1. **MUST check for an existing agent in the current cluster (any type) before creating anything.** If a Testkube
   agent is running in the active kube context — minikube, kind, k3d, or remote — and `testkube version` shows a
   server version, reuse it; do not spin up a new cluster or redeploy.
2. **MUST confirm every mutating step with the user before running it.** Installing k3d, creating a cluster, deploying
   the agent, and teardown all change the local system — describe the exact command and wait for the user's go-ahead
   before each one.
3. **MUST reuse existing pieces individually.** If you already have a running cluster (minikube/kind/k3d/remote),
   deploy into it instead of creating one. Skip k3d install if `k3d` is on PATH; skip cluster create if a usable
   cluster exists; skip `testkube init standalone-agent` if the agent is already Running.
4. **MUST verify before reporting success.** `testkube version` must print both a client and a server version.
5. **MUST NOT tear down without explicit confirmation.** `testkube purge` and cluster delete commands destroy the
   local environment — never run them unprompted.
6. **The user must approve the init step (Rule 2) — but that approval need not be typed into the CLI's own prompt.**
   `testkube init standalone-agent` reads its `[Y/n]` prompt from the terminal, so in a non-interactive / agent / CI
   shell it hangs (piping `yes` does not help). Never skip the user's approval. Once they have approved, run
   non-interactively via the Helm alternative or with `--no-confirm` — the human approval is what matters, not who
   types `Y`. Leave the prompt for the user to answer only when a real human is interacting with the terminal.
7. **REQUIRED SUB-SKILL:** the Testkube CLI must be present — use installing-testkube-cli. Also needs `kubectl`,
   `helm`, and `curl` on PATH. Docker (`docker info`) is required only when creating a k3d cluster. `k3d` is installed
   by step 3 when needed.

## Helm alternative (Step 5)

Equivalent to `testkube init standalone-agent`, useful for pinning chart values / CI:

```bash
helm repo add kubeshop https://kubeshop.github.io/helm-charts
helm repo update
helm upgrade --install testkube kubeshop/testkube \
  --create-namespace \
  --namespace testkube \
  --set installCRDs=true
```

## Teardown

Destructive — **confirm with the user first** (Rule 5).

1. **Remove the agent** (any cluster type):
   ```bash
    TK_CMD="$(command -v testkube || command -v tk || command -v kubectl-testkube)"
    if [ -n "$TK_CMD" ]; then "$TK_CMD" purge; else echo "Testkube CLI not found; use installing-testkube-cli"; fi  # or: helm delete --namespace testkube testkube
   ```

2. **Delete the cluster only if this skill created it** — match the cluster type from setup:
   - **k3d** (created in step 4): `k3d cluster delete testkube`
   - **minikube**: `minikube delete` (or the profile-specific delete command)
   - **kind**: `kind delete cluster --name <cluster-name>`
   - **Remote / shared cluster**: do **not** delete the cluster — only purge the agent unless the user explicitly asks
     to remove the whole cluster.

## Common Mistakes

- **Creating a new cluster when an agent already runs elsewhere** — the step-2 check is cluster-agnostic; if minikube,
  kind, or a remote cluster already has the agent, switch context and reuse it instead of spinning up k3d. List
  clusters with `kubectl config get-contexts` (and `k3d cluster list` for k3d specifically).
- **`docker info` fails / k3d cluster create hangs** — Docker isn't running. k3d needs a live Docker daemon; start Docker
  Desktop or `systemctl start docker` first. Docker is not required when reusing an existing remote/minikube/kind cluster.
- **`testkube: command not found`** — the CLI isn't installed; see installing-testkube-cli.
- **Using bare `testkube init`** — current CLI requires a profile; use `testkube init standalone-agent` (alias: `oss`)
  for OSS standalone mode.
- **Aborted `init` leaves orphaned processes / a stuck Helm release** — killing the wrapper of an `init` attempt
  (TaskStop, Ctrl-C, timeout) can leave `testkube init` child processes running that still hold a Helm lock, so the
  next attempt fails with `another operation (install/upgrade/rollback) is in progress`. Before retrying:
  `pkill -f 'testkube init'`, then check `helm list -n testkube` for a stuck release and `helm uninstall` (or roll
  back) it. This is also why a non-interactive install path (Helm, or `--no-confirm` after approval) is safer than
  leaving the CLI hung on its TTY prompt.
- **`testkube version` shows no server version** — kubeconfig points at the wrong context, or the agent pods aren't
  `Running` yet. Run `kubectl config get-contexts` to identify the cluster with the agent, switch to it with
  `kubectl config use-context <context-with-the-agent>`, and re-check `kubectl get pods -n testkube`.
- **Expecting a dashboard** — standalone/OSS mode has none. The dashboard ships with the Testkube Control Plane, a
  separate install (see https://docs.testkube.io/articles/install/overview).
