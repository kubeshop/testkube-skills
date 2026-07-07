# Examples Catalog

Quick-lookup index for the 22 example TestWorkflows in `examples/`. Each example demonstrates specific patterns. Find
the one that matches your needs.

## By Content Source

For Git-based content delivery, see the "Git checkout" examples below by pattern.

## By Example

| Example                      | Tool            | Key Patterns                                                | Complexity |
| ---------------------------- | --------------- | ----------------------------------------------------------- | ---------- |
| `k6-inline.yaml`             | K6              | inline content, config, shell, artifacts                    | simple     |
| `playwright-git.yaml`        | Playwright      | git, run with env, nested steps, artifacts                  | medium     |
| `cypress-git.yaml`           | Cypress         | git, run with shell+env, nested steps                       | medium     |
| `postman-git.yaml`           | Postman         | git, shell, activeDeadlineSeconds                           | simple     |
| `jmeter-template.yaml`       | JMeter          | template usage, artifacts, config                           | medium     |
| `go-build-lint.yaml`         | Go              | multi-step, different images, run with shell                | medium     |
| `suite-execute.yaml`         | Suite           | execute composition, parallelism                            | simple     |
| `selenium-services.yaml`     | Selenium        | services (sidecar), readinessProbe, service IP              | complex    |
| `healthcheck-config.yaml`    | Shell           | config, secrets (valueFrom), optional, expressions          | medium     |
| `cron-trigger.yaml`          | Shell           | events, cronjob, scheduled execution                        | simple     |
| `parallel-matrix.yaml`       | Cypress         | parallel, matrix, transfer, fetch, expressions              | complex    |
| `distributed-k6.yaml`        | K6              | distribute/evenly, paused, index/count, config-driven count | complex    |
| `pod-volumes.yaml`           | Cypress         | pod.volumes, emptyDir, volumeMounts, /dev/shm               | medium     |
| `command-args.yaml`          | Postman         | command, args, entrypoint-based, shell vs args              | simple     |
| `step-level-use.yaml`        | K6              | use at step level, template scoping                         | medium     |
| `gradle-java.yaml`           | Gradle          | gradle, --no-daemon, build tool image                       | simple     |
| `maven-java.yaml`            | Maven           | maven, surefire reports, JUnit auto-parse                   | simple     |
| `artillery-distributed.yaml` | Artillery       | distributed, config-driven, transfer, index/count           | complex    |
| `locust-load-test.yaml`      | Locust          | locust, run with image, HTML report                         | simple     |
| `robot-framework.yaml`       | Robot Framework | xunit/JUnit, --exclude tags, specialized image              | medium     |
| `k6-browser.yaml`            | K6              | k6-browser, specialized image, JSON output                  | simple     |
| `content-file-mixed.yaml`    | K6              | content.files, per-step workingDir, step-level image        | medium     |

## By Pattern

Use this section to find examples by the pattern you need.

### Content Sources

- **Inline script (no Git)**: `k6-inline.yaml`
- **Git checkout (public repo)**: `playwright-git.yaml`, `cypress-git.yaml`, `postman-git.yaml`, `go-build-lint.yaml`
- **Git checkout (private repo with secrets)**: see `references/schema.md` §Content Sources for git auth patterns

### Step Types

- **Simple shell**: `k6-inline.yaml`, `postman-git.yaml`, `cron-trigger.yaml`
- **Run with custom image**: `go-build-lint.yaml`, `cypress-git.yaml`
- **Template usage**: `jmeter-template.yaml`
- **Execute (suite)**: `suite-execute.yaml`

### Advanced Features

- **Config + expressions**: `k6-inline.yaml`, `healthcheck-config.yaml`
- **Artifact collection**: `k6-inline.yaml`, `playwright-git.yaml`, `cypress-git.yaml`,
  `jmeter-template.yaml`, `selenium-services.yaml`
- **Services (sidecars)**: `selenium-services.yaml`
- **Secrets (valueFrom)**: `healthcheck-config.yaml`
- **Cron trigger**: `cron-trigger.yaml`
- **Parallel + matrix + transfer/fetch**: `parallel-matrix.yaml`, `distributed-k6.yaml`, `artillery-distributed.yaml`
- **Pod volumes / /dev/shm**: `pod-volumes.yaml`
- **Command/args (non-shell)**: `command-args.yaml`
- **Step-level template use**: `step-level-use.yaml`

### Build Tools

- **Gradle**: `gradle-java.yaml`
- **Maven**: `maven-java.yaml`

### Specialized Tools

- **Artillery**: `artillery-distributed.yaml`
- **Locust**: `locust-load-test.yaml`
- **Robot Framework**: `robot-framework.yaml`
- **K6 Browser**: `k6-browser.yaml`
- **Setup/After hooks**: see step-patterns.md Pattern 12
