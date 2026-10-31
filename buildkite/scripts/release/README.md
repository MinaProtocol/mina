# Mina Protocol Release Manager

Comprehensive release management tool that handles the complete lifecycle of build artifacts including publishing, promotion, verification, and maintenance of packages across different channels and platforms.

## Overview

The release manager script (`manager.sh`) provides functionality to:

- **PUBLISH**: Publish build artifacts from cache to Debian repositories and Docker registries
- **PROMOTE**: Promote artifacts from one channel/registry to another (e.g., unstable → stable)
- **VERIFY**: Verify that artifacts are correctly published in target channels/registries
- **FIX**: Repair Debian repository manifests when needed
- **PERSIST**: Archive artifacts to long-term storage backends
- **PULL**: Download artifacts from storage backends

## Supported Components

- **Artifacts**: `mina-daemon`, `mina-archive`, `mina-rosetta`, `mina-logproc`
- **Networks**: `devnet`, `mainnet`
- **Platforms**: Debian (bullseye, focal, noble, bookworm, jammy), Docker (GCR, Docker.io)
- **Channels**: `unstable`, `alpha`, `beta`, `stable`
- **Storage Backends**: Google Cloud Storage (`gs`), Hetzner (`hetzner`), local filesystem (`local`)
- **Architectures**: `amd64`, `arm64`

## Prerequisites

### Host Environment Requirements

The release manager must be run on a host with the following prerequisites:

#### Required Software

1. **Docker Engine** (for verification and Docker operations)
   ```bash
   # Verify Docker is installed and running
   docker --version
   docker ps
   ```

2. **Google Cloud SDK** (for `gs` backend operations)
   ```bash
   # Install gcloud SDK
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud auth login

   # Verify gsutil is available
   gsutil --version
   ```

3. **SSH Access** (for Hetzner backend)
   ```bash
   # Ensure SSH key is configured for Hetzner
   ssh -i ~/.ssh/id_rsa -p 23 u434410@u434410-sub2.your-storagebox.de
   ```

4. **deb-s3** (for Debian repository operations)
   ```bash
   gem install deb-s3
   ```

#### Environment Variables

```bash
# For Hetzner backend operations
export HETZNER_KEY=...
export HETZNER_USER=u434410
export HETZNER_HOST=u434410-sub2.your-storagebox.de

# For Debian cache (optional, defaults to ~/.release/debian/cache)
export DEBIAN_CACHE_FOLDER=~/.release/debian/cache

# Set aws env vars as we need to upload debians to our debian repositories
export AWS_ACCESS_KEY_ID=..
export AWS_SECRET_ACCESS_KEY..

```

#### Debian key

Ensure you imported debian key from gcloud secret:

```bash
# Import Debian signing key from Google Cloud Secret Manager
gcloud secrets versions access latest --secret="o1labsDebianRepoKey" | gpg --import

# Verify key was imported
gpg --list-secret-keys

# Alternative: Import from local file
gpg --import ~/.gnupg/debian-signing-key.asc
```

#### Directory Permissions

Ensure the script has write access to:
- `~/.release/debian/cache` (or custom `DEBIAN_CACHE_FOLDER`)
- Temporary directories for artifact processing

#### Network Access

- Internet connectivity for downloading artifacts
- Access to Google Cloud Storage (if using `gs` backend)
- SSH access to Hetzner storage box (if using `hetzner` backend)
- Access to Docker registries (GCR, Docker.io)
- Access to Debian repositories

## Command Reference

### 1. PUBLISH Command

Publishes build artifacts from cache storage to Debian repositories and Docker registries.

#### Syntax
```bash
./manager.sh publish [OPTIONS]
```

#### Required Parameters
- `--buildkite-build-id <ID>`: BuildKite build ID containing the artifacts to publish
- `--source-version <VERSION>`: Source version of the build artifacts
- `--target-version <VERSION>`: Target version for published artifacts. Debian packages are uploaded as built, so it must equal `--source-version` unless `--only-dockers` is set (docker images can be retagged)
- `--channel <CHANNEL>`: Target Debian channel (unstable, alpha, beta, stable)

#### Optional Parameters
- `--artifacts <LIST>`: Comma-separated list of artifacts (default: all)
- `--networks <LIST>`: Comma-separated list of networks (default: devnet,mainnet)
- `--codenames <LIST>`: Debian codenames (default: bullseye,focal)
- `--arch <ARCH>`: Target architecture (default: amd64)
- `--backend <BACKEND>`: Storage backend - `gs`, `hetzner`, or `local` (default: gs)
- `--debian-repo <REPO>`: Debian repository URL (default: packages.o1test.net)
- `--debian-sign-key <KEY>`: GPG signing key for Debian packages
- `--publish-to-docker-io`: Publish to docker.io instead of GCR
- `--only-dockers`: Publish only Docker images
- `--only-debians`: Publish only Debian packages
- `--verify`: Verify packages after publishing
- `--dry-run`: Show what would be published without executing
- `--force-upload-debians`: Force upload even if packages exist

#### Backend Parameter Details

The `--backend` parameter is **crucial** and determines where artifacts are sourced from:

- **`gs` (Google Cloud Storage)**: Default backend, requires `gsutil` authentication
  ```bash
  --backend gs
  ```

- **`hetzner`**: Uses Hetzner storage box via SSH
  ```bash
  --backend hetzner
  ```

- **`local`**: Uses local filesystem storage
  ```bash
  --backend local
  ```

#### Examples

**Basic publish to stable channel:**
```bash
./manager.sh publish \
  --buildkite-build-id 12345 \
  --source-version 2.0.0 \
  --target-version 2.0.0 \
  --channel stable \
  --verify
```

**Publish specific artifacts with custom backend:**
```bash
./manager.sh publish \
  --artifacts mina-daemon,mina-archive \
  --networks mainnet \
  --buildkite-build-id 12345 \
  --source-version 2.0.0 \
  --target-version 2.0.0 \
  --channel stable \
  --backend hetzner \
  --codenames bullseye \
  --verify
```

**Publish only Docker images to docker.io:**
```bash
./manager.sh publish \
  --buildkite-build-id 12345 \
  --source-version 2.0.0-rc1 \
  --target-version 2.0.0 \
  --channel stable \
  --only-dockers \
  --publish-to-docker-io \
  --verify
```

**Dry run to test configuration:**
```bash
./manager.sh publish \
  --buildkite-build-id 12345 \
  --source-version 2.0.0 \
  --target-version 2.0.0 \
  --channel stable \
  --dry-run
```

### 2. PROMOTE Command

Promotes artifacts from one channel/registry to another without requiring build cache access.

#### Syntax
```bash
./manager.sh promote [OPTIONS]
```

#### Required Parameters
- `--source-version <VERSION>`: Source version to promote from
- `--target-version <VERSION>`: Target version to promote to
- `--source-channel <CHANNEL>`: Source Debian channel (for Debian packages)
- `--target-channel <CHANNEL>`: Target Debian channel (for Debian packages)

#### Optional Parameters
- `--artifacts <LIST>`: Artifacts to promote (default: all)
- `--networks <LIST>`: Networks to promote (default: devnet,mainnet)
- `--codenames <LIST>`: Debian codenames (default: bullseye,focal)
- `--arch <ARCH>`: Architecture (default: amd64)
- `--debian-repo <REPO>`: Debian repository URL
- `--debian-sign-key <KEY>`: GPG signing key
- `--publish-to-docker-io`: Promote Docker images to docker.io
- `--only-dockers`: Promote only Docker images
- `--only-debians`: Promote only Debian packages
- `--verify`: Verify promoted packages
- `--dry-run`: Show promotion plan without executing

#### Examples

**Promote from alpha to beta:**
```bash
./manager.sh promote \
  --source-version 2.0.0-rc1 \
  --target-version 2.0.0-rc2 \
  --source-channel alpha \
  --target-channel beta \
  --verify
```

**Promote Docker images from GCR to docker.io:**
```bash
./manager.sh promote \
  --source-version 2.0.0 \
  --target-version 2.0.0 \
  --source-channel stable \
  --target-channel stable \
  --only-dockers \
  --publish-to-docker-io \
  --verify
```

### 3. VERIFY Command

Verifies that artifacts are correctly published in target channels/registries.

#### Syntax
```bash
./manager.sh verify [OPTIONS]
```

#### Required Parameters
- `--version <VERSION>`: Version to verify

#### Optional Parameters
- `--artifacts <LIST>`: Artifacts to verify (default: all)
- `--networks <LIST>`: Networks to verify (default: devnet,mainnet)
- `--codenames <LIST>`: Debian codenames (default: bullseye,focal)
- `--channel <CHANNEL>`: Debian channel (default: unstable)
- `--arch <ARCH>`: Architecture (default: amd64)
- `--debian-repo <REPO>`: Debian repository URL
- `--docker-io`: Verify Docker images on docker.io instead of GCR
- `--only-dockers`: Verify only Docker images
- `--only-debians`: Verify only Debian packages
- `--docker-suffix <SUFFIX>`: Additional suffix for Docker tags
- `--signed-debian-repo`: Verify signed Debian repository

#### Examples

**Verify stable release:**
```bash
./manager.sh verify \
  --version 2.0.0 \
  --channel stable \
  --codenames bullseye,focal
```

**Verify Docker images on docker.io:**
```bash
./manager.sh verify \
  --version 2.0.0 \
  --only-dockers \
  --docker-io
```

### 4. FIX Command

Repairs Debian repository manifests when they become corrupted or inconsistent.

#### Syntax
```bash
./manager.sh fix [OPTIONS]
```

#### Required Parameters
- `--channel <CHANNEL>`: Channel to fix
- `--codenames <LIST>`: Codenames to fix (default: bullseye,focal)

#### Examples

**Fix stable channel manifests:**
```bash
./manager.sh fix \
  --channel stable \
  --codenames bullseye,focal
```

### 5. PERSIST Command

Archives artifacts from cache to long-term storage with optional version modification.

#### Syntax
```bash
./manager.sh persist [OPTIONS]
```

#### Required Parameters
- `--buildkite-build-id <ID>`: Source build ID
- `--target <PATH>`: Target storage path
- `--codename <CODENAME>`: Debian codename
- `--artifacts <LIST>`: Artifacts to persist

#### Optional Parameters
- `--backend <BACKEND>`: Storage backend (default: hetzner)
- `--new-version <VERSION>`: New version for repackaged artifacts
- `--suite <SUITE>`: Debian suite (default: unstable)
- `--arch <ARCH>`: Architecture (default: amd64)

#### Examples

**Archive build artifacts:**
```bash
./manager.sh persist \
  --backend hetzner \
  --buildkite-build-id 12345 \
  --target /archive/2024/releases \
  --codename bullseye \
  --artifacts mina-daemon,mina-archive
```

**Archive with version change:**
```bash
./manager.sh persist \
  --buildkite-build-id 12345 \
  --target /archive/legacy \
  --codename bullseye \
  --artifacts mina-daemon \
  --new-version 1.9.9-legacy \
  --suite stable
```

### 6. PULL Command

Downloads artifacts from storage backends to local filesystem.

#### Syntax
```bash
./manager.sh pull [OPTIONS]
```

#### Required Parameters
- `--buildkite-build-id <ID>` OR `--from-special-folder <PATH>`: Source location
- `--target <PATH>`: Local target directory

#### Optional Parameters
- `--backend <BACKEND>`: Storage backend (default: hetzner)
- `--artifacts <LIST>`: Artifacts to pull (default: all)
- `--codenames <LIST>`: Codenames to pull (default: bullseye,focal)
- `--networks <LIST>`: Networks to pull (default: devnet,mainnet)

#### Examples

**Pull build artifacts locally:**
```bash
./manager.sh pull \
  --backend gs \
  --buildkite-build-id 12345 \
  --target ./artifacts \
  --artifacts mina-daemon,mina-archive
```

**Pull from special archive folder:**
```bash
./manager.sh pull \
  --backend hetzner \
  --from-special-folder /archive/legacy \
  --target ./legacy-artifacts \
  --codenames bullseye
```

## Storage Backend Configuration

### Google Cloud Storage (gs)
```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud config set project o1labs-192920

# Storage root: gs://buildkite_k8s/coda/shared
```

### Hetzner Storage
```bash
# SSH key configuration
export HETZNER_KEY=~/.ssh/id_rsa
export HETZNER_USER=u434410
export HETZNER_HOST=u434410-sub2.your-storagebox.de

# Storage root: /home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1
```

### Local Storage
```bash
# Storage root: /var/storagebox/
# Ensure directory exists and has proper permissions
sudo mkdir -p /var/storagebox
sudo chown $USER:$USER /var/storagebox
```

## Common Workflows

### Release Process: Unstable → Stable

1. **Publish to unstable** (from CI build):
   ```bash
   ./manager.sh publish \
     --buildkite-build-id 12345 \
     --source-version 2.0.0-rc1 \
     --target-version 2.0.0-rc1 \
     --channel unstable \
     --verify
   ```

2. **Promote to alpha** (for testing):
   ```bash
   ./manager.sh promote \
     --source-version 2.0.0-rc1 \
     --target-version 2.0.0-rc1 \
     --source-channel unstable \
     --target-channel alpha \
     --verify
   ```

3. **Promote to stable** (for production):
   ```bash
   ./manager.sh promote \
     --source-version 2.0.0-rc1 \
     --target-version 2.0.0 \
     --source-channel alpha \
     --target-channel stable \
     --verify
   ```

4. **Publish to docker.io** (for public access):
   ```bash
   ./manager.sh promote \
     --source-version 2.0.0 \
     --target-version 2.0.0 \
     --source-channel stable \
     --target-channel stable \
     --only-dockers \
     --publish-to-docker-io \
     --verify
   ```

### Emergency Fix Workflow

If repository manifests become corrupted:

```bash
# Fix manifests
./manager.sh fix \
  --channel stable \
  --codenames bullseye,focal

# Verify everything is working
./manager.sh verify \
  --version 2.0.0 \
  --channel stable
```

## Troubleshooting

### Common Issues

1. **"No debian package found"**: Check build ID and backend connectivity
2. **"gsutil program not found"**: Install Google Cloud SDK
3. **Docker verification fails**: Ensure Docker engine is running
4. **SSH connection issues**: Verify Hetzner SSH key and permissions
5. **Repository manifest errors**: Use `fix` command to repair

### Debug Mode

The script runs with `set -x` enabled, showing all executed commands. For additional debugging:

```bash
# Check artifact availability
./manager.sh pull --buildkite-build-id 12345 --target /tmp/test --dry-run

# Verify backend connectivity
gsutil ls gs://buildkite_k8s/coda/shared/  # For gs backend
ssh -p23 -i $HETZNER_KEY $HETZNER_USER@$HETZNER_HOST "ls /"  # For hetzner
```

### Log Analysis

Monitor the script output for:
- `❌` Error indicators
- `⚠️` Warning messages
- `✅` Success confirmations
- `📦` Artifact processing
- `🐋` Docker operations
- `🍥` Debian operations

## Security Considerations

- GPG signing keys should be properly secured
- SSH keys for Hetzner access should use strong passphrases
- Google Cloud credentials should follow principle of least privilege
- Never commit signing keys or credentials to version control
- Use `--dry-run` to verify operations before execution

## Version Compatibility

This documentation applies to CLI version 1.0.0 of the release manager script. Check version with:

```bash
./manager.sh version
```
