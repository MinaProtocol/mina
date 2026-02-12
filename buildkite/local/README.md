# Local Buildkite Job Runner

Run Buildkite CI jobs locally for development and debugging without pushing to CI.

## Quick Start

```bash
# One-time setup (see Prerequisites below)
sudo mkdir -p /var/storagebox /var/buildkite/shared
sudo chown $(id -u):$(id -g) /var/storagebox /var/buildkite/shared

# List available jobs
./run_job.sh --list

# Dry-run to see what commands would execute
./run_job.sh --dry-run MinaArtifactBullseyeDevnet

# Run a specific job
./run_job.sh MinaArtifactBullseyeDevnet

# Run with custom environment variables
cat > my-env.txt << 'EOF'
NETWORK=Devnet
VERSION=4.0.0-test
CODENAMES=Noble
EOF
./run_job.sh --env-file ./my-env.txt HardforkPackageGenerationNew
```

## Prerequisites

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| `yq` | YAML processing | https://github.com/mikefarah/yq |
| `dhall-to-yaml` | Pipeline generation | https://github.com/dhall-lang/dhall-haskell |
| `docker` | Container execution | https://docs.docker.com/get-docker/ |
| `rsync` | Cache sync from Hetzner | Usually pre-installed |
| `aptly` | Local Debian repository (inside container) | Pre-installed in mina-toolchain image |

**Port requirement:** Port `8080` must be available. Aptly starts a local Debian
repository server on this port during hardfork package generation.

### Required Directories (Permissions)

The script does **not** use `sudo` during execution. Instead, certain directories
must be pre-created and owned by your user. This design:

- Avoids password prompts during long builds
- Prevents accidental permission escalation
- Makes the script safe to run in automated contexts

**One-time setup:**

```bash
# Create and own the local cache directory
sudo mkdir -p /var/storagebox
sudo chown $(id -u):$(id -g) /var/storagebox

# Create and own the shared state directory
sudo mkdir -p /var/buildkite/shared
sudo chown $(id -u):$(id -g) /var/buildkite/shared
```

| Directory | Purpose | Why Writable? |
|-----------|---------|---------------|
| `/var/storagebox` | Local mirror of CI cache | Stores build artifacts, debian packages, and cached dependencies. The cache manager creates per-build subdirectories here. |
| `/var/buildkite/shared` | Shared state between steps | Used for lock files, inter-step communication, and temporary data that persists across build steps. |
| `_build/` (in repo) | Compilation artifacts | Bind-mounted into Docker containers. Must be owned by your UID or containers cannot write build outputs. |

If any directory is missing or not writable, the script will fail with a clear
error message showing the exact command to fix it.

### Hetzner Cache Access

To sync the legacy cache from Hetzner (contains pre-built dependencies):

1. Obtain the storagebox SSH key
2. Place it at `~/work/secrets/storagebox.key` (or set `HETZNER_KEY`)

Use `--skip-sync` if you don't have access or don't need the legacy cache.

## Limitations vs CI

Local execution differs from CI in several ways:

### Docker UID Mapping

**CI behavior:** Containers run as the `opam` user (UID 1000 inside container).

**Local behavior:** Containers also run as `opam` (UID 1000). This allows sudo
to work inside containers for apt operations.

If your host user has a different UID than 1000, you may see permission issues
with the `_build` directory. The script checks for this at startup and will
show an error with instructions to fix ownership.

### Environment Variables

The script sets `LOCAL_BK_RUN=1` which build scripts can check to detect
local execution and adjust behavior accordingly.

### Cache Behavior

**CI:** Uses Hetzner storagebox directly via network mounts.

**Local:** Syncs a local copy to `/var/storagebox`. First sync may be slow.

### Parallelism

CI runs steps on multiple agents in parallel. Locally, steps run sequentially
in a single process.

## Environment Variables

### Auto-computed from Git

These are derived from your local git state:

| Variable | Source |
|----------|--------|
| `BUILDKITE_BRANCH` | Current branch |
| `BUILDKITE_COMMIT` | HEAD commit SHA |
| `BUILDKITE_MESSAGE` | Last commit message |
| `BUILDKITE_BUILD_AUTHOR` | Last commit author name |
| `BUILDKITE_BUILD_AUTHOR_EMAIL` | Last commit author email |
| `BUILDKITE_TAG` | Tag pointing at HEAD (if any) |
| `BUILDKITE_REPO` | Origin remote URL |

### Generated Per-run

| Variable | Description |
|----------|-------------|
| `BUILDKITE_BUILD_ID` | Random UUID for this build (or value from `--build-id`) |
| `BUILDKITE_JOB_ID` | Random UUID for this job |
| `BUILDKITE_AGENT_ID` | Random UUID for this agent |
| `BUILDKITE_BUILD_NUMBER` | Unix timestamp |

### Local-only Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCAL_BK_RUN` | `1` | Indicates local execution (scripts can check this) |
| `SKIP_DOCKER_PRUNE` | `1` | Prevents docker system prune |
| `GIT_LFS_SKIP_SMUDGE` | `1` | Skips LFS file download |
| `APTLY_ROOT` | `/tmp/aptly` | Writable directory for aptly database (avoids ~/.aptly permission issues) |

### Cache Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `HETZNER_KEY` | `~/work/secrets/storagebox.key` | SSH key for Hetzner |
| `HETZNER_USER` | `u434410` | Hetzner username |
| `HETZNER_HOST` | `u434410-sub2.your-storagebox.de` | Hetzner host |
| `CI_CACHE_ROOT` | `/home/o1labs-generic/pvc-4d294645-...` | Remote cache path on Hetzner |
| `CACHE_BASE_URL` | `/var/storagebox` | Local cache directory |

### Custom Environment Variables (--env-file)

The `--env-file` option accepts a file with `KEY=VALUE` pairs. These variables are:

1. **Exported to the shell** - Available to all non-Docker commands
2. **Passed to Docker containers** - Automatically added as `--env KEY` flags

This ensures your custom variables are available everywhere, including inside
Docker containers where most build steps execute.

**File format:**

```bash
# Comments are ignored
NETWORK=Devnet
VERSION=4.0.0-fake-e44eefb
CODENAMES=Noble

# Values can contain special characters
CONFIG_JSON_GZ_URL=https://storage.googleapis.com/bucket/file.json.gz
GENESIS_TIMESTAMP=2026-01-27T19:30:00Z
```

**Example env file for hardfork jobs:**

```bash
# my-hardfork-env.txt
REPO=Nightly
NETWORK=Devnet
VERSION=4.0.0-test-abc1234
CODENAMES=Noble
GENESIS_TIMESTAMP=2026-01-27T19:30:00Z
CONFIG_JSON_GZ_URL=https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/ledger.json.gz
MINA_LEDGER_S3_BUCKET=https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net
PRECOMPUTED_FORK_BLOCK_PREFIX=gs://mina_network_block_data/devnet
```

**Usage:**

```bash
./run_job.sh --env-file ./my-hardfork-env.txt HardforkPackageGenerationNew
```

The script will print which variables were loaded:

```
Loading env file: ./my-hardfork-env.txt
User env vars: REPO NETWORK VERSION CODENAMES GENESIS_TIMESTAMP CONFIG_JSON_GZ_URL
```

## Command Reference

```
Usage: run_job.sh [options] <job-name>

Options:
  --dry-run          Print commands without executing
  --skip-dump        Skip pipeline generation (reuse --jobs-dir)
  --skip-sync        Skip legacy folder sync from Hetzner
  --jobs-dir DIR     Path to pre-generated pipeline YAMLs
  --step KEY         Run only the step matching this key (substring match)
  --start-from KEY   Start execution from this step (skip all previous steps)
  --build-id ID      Reuse a specific BUILDKITE_BUILD_ID (for resuming/debugging)
  --env-file FILE    File with KEY=VALUE pairs passed to all commands (including Docker)
  --list             List available job names and exit
  --list-steps       List steps in the job and exit (requires job name)
  -h, --help         Show this help
```

### Examples

```bash
# List all available jobs
./run_job.sh --list

# List jobs without regenerating pipelines (faster)
./run_job.sh --list --jobs-dir ./jobs

# List steps in a specific job
./run_job.sh --list-steps GenerateHardforkPackage

# List steps without regenerating pipelines
./run_job.sh --list-steps --jobs-dir ./jobs GenerateHardforkPackage

# See what commands a job would run
./run_job.sh --dry-run MinaArtifactBullseyeDevnet

# Run a specific step within a job
./run_job.sh --step "build-deb-pkg" MinaArtifactBullseyeDevnet

# Start from a specific step (skip earlier steps)
./run_job.sh --start-from "upload-ledger" GenerateHardforkPackage

# Resume a failed build using the same build ID
./run_job.sh --build-id abc123-def456 --start-from "step-3" GenerateHardforkPackage

# Reuse previously generated pipelines (faster iteration)
./run_job.sh --skip-dump --jobs-dir /tmp/pipelines MinaArtifactBullseyeDevnet

# Skip Hetzner sync (if you don't need legacy cache)
./run_job.sh --skip-sync MinaArtifactBullseyeDevnet

# Run with custom environment variables
./run_job.sh --env-file ./my-env.txt --step "build-deb-pkg-noble" HardforkPackageGenerationNew

# Full example: resume a hardfork build from a specific step
./run_job.sh --build-id 465d2528-715f-4b01-8ee6-18bbac491a7a \
    --skip-sync --skip-dump --jobs-dir ./jobs \
    --start-from "_GenerateHardforkPackage-build-hf-debian-noble" \
    GenerateHardforkPackage
```

### Resuming Builds

The `--build-id` and `--start-from` options work together to resume failed or interrupted builds:

1. **Note the build ID** from your original run (printed at startup)
2. **List steps** to find where to resume: `./run_job.sh --list-steps --jobs-dir ./jobs JobName`
3. **Resume** with: `./run_job.sh --build-id <id> --start-from <step-key> JobName`

This is useful for:
- **Resuming failed builds** - continue from where it failed without re-running earlier steps
- **Debugging** - re-run a specific step with the same artifact paths
- **Iterating** - make changes and re-run only the affected steps

## Troubleshooting

### Permission denied errors

```
ERROR: Local storagebox directory is not writable: /var/storagebox
```

Run the one-time setup commands in Prerequisites above.

### _build owned by different user

```
ERROR: _build directory is owned by UID 0 (you are 1000)
```

This happens when a previous Docker run created files as root. Fix with:

```bash
sudo chown -R $(id -u):$(id -g) _build
```

### Hetzner key not found

```
ERROR: Hetzner key not found at: ~/work/secrets/storagebox.key
```

Either obtain the key or use `--skip-sync` to skip cache sync.

### yq not found

Install from https://github.com/mikefarah/yq:

```bash
# Linux
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
```

### Docker permission denied

Ensure your user is in the `docker` group:

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

## Files

| File | Description |
|------|-------------|
| `run_job.sh` | Main script |
