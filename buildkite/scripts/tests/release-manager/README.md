# Release Manager Test Suite

This directory contains automated tests for the Mina Protocol release manager (`buildkite/scripts/release/manager.sh`).

## Overview

The release manager test suite verifies that the release manager script and its helper scripts function correctly for publishing and promoting Debian packages and Docker images. The tests run against a test Debian repository to ensure safe testing without affecting production repositories.

## Test Script

**Location**: `buildkite/scripts/tests/release-manager-test.sh`

### Test Coverage

The test suite includes the following test cases:

**Dry-run Tests (Safe, read-only or simulated operations):**
1. **List Packages**: Verifies ability to list packages in the test repository
2. **Verify Test Packages**: Confirms that test packages exist in the CI component
3. **Manager Verify Command (Dry-run)**: Tests the verify command without making changes
4. **Manager Promote Command - Unsigned (Dry-run)**: Tests promotion in unsigned repository with random version suffix
5. **Manager Promote Command - Signed (Dry-run)**: Tests promotion in signed repository with GPG signing key
6. **Manager Publish Command - Signed (Dry-run)**: Tests publishing to signed repository with GPG signing key

The suite also covers the per-artifact dry-run cases in `run_dry_run_tests`
(`mina-config`, `mina-generic`, `rosetta-generic`, `mina-automode`, mixed
artifact lists, and rejection of an unknown artifact). The two `mina-automode`
cases pin the docker image name: that artifact publishes as
`mina-daemon-auto-hardfork`, not under its own name, so they assert the exact
`mina-daemon-auto-hardfork:<version>-<codename>-<network>` tag appears in the
publish and promote output.

**Non-dry-run Tests (Actual operations that make changes):**
7. **Manager Promote - Unsigned (Real)**: Actually promotes packages in unsigned test repository with verification
8. **Manager Promote - Signed (Real)**: Actually promotes packages in signed test repository with GPG signing and verification
9. **Docker Promote to GCP**: Pulls Docker image from Docker Hub (`minaprotocol/mina-daemon:3.3.0-8c0c2e6-bookworm-mainnet-arm64`) and pushes to GCP Artifact Registry (`europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-daemon:random-tag`)

### Test Configuration

Both Debian repositories are **mocked**. `mock-repo.sh` starts a MinIO container
for the duration of the run, creates the two buckets in it, and seeds them with
fixture packages it builds itself. Nothing outside the run is read or written,
so the tests need no AWS account, no live bucket, and no production signing key.

The mock is reached in two ways at once:

| Reader | Address | Why |
|---|---|---|
| `deb-s3`, `aws`, the test scripts | `http://127.0.0.1:<ephemeral>` | They run on the agent and use the published port. |
| `apt` inside a verification container | `http://mina-release-mock-repo-<pid>:9000` | It is a sibling container on the mock's docker network. |

The port is chosen by docker at run time, so parallel agents never collide.

**Unsigned Repository:**
- **Test Bucket**: `test-packages` (in the mock)
- **Test Region**: `us-west-2` (claimed, not used - MinIO ignores it)
- **Test Codename**: `bookworm`
- **Test Component (CI)**: `ci`
- **Test Component (Promote Target)**: `test`
- **Test Architecture**: `amd64`

**Signed Repository:**
- **Test Bucket**: `signed-test-packages` (in the mock)
- **Test Codename**: `bookworm`
- **Test Component**: `test`
- **Signing Key**: generated per run, discarded at the end
- **Test Architecture**: `arm64`

**Why the repository is served over plain HTTP**

The retired buckets were served over HTTPS. A base image without a trust store
therefore failed with `Certificate verification failed: The certificate is NOT
trusted`, whatever the real cause was. Over HTTP the verification container
needs no `ca-certificates` and, for an unsigned repository, contacts the Debian
archive not at all. See `scripts/debian/verify-inside-docker/setup.sh`, which
now installs only the packages the repository URL actually requires.

**Docker Configuration:**
- **Source Registry**: Docker Hub (`minaprotocol`)
- **Source Image**: `mina-daemon`
- **Source Tag**: `3.3.0-8c0c2e6-bookworm-mainnet-arm64` (always exists)
- **Target Registry**: GCP Artifact Registry (`europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo`)
- **Target Image**: `mina-daemon`
- **Target Tag**: Uses random suffix `test-<timestamp>-<random>`

**Version Naming:**
- Promote operations use random suffixes: `test-<timestamp>-<random>`
- This ensures each test run creates unique versions without conflicts
- Real (non-dry-run) promotions add `-real` or `-signed-real` to the suffix

### Test Packages and Images

**Debian Packages:**

`mock-repo.sh` builds these with `dpkg-deb` at the start of every run and seeds
them into the `bookworm/ci` component. Nothing has to be uploaded by hand.

| Package | Version | Arch | Repository |
|---|---|---|---|
| `mina-devnet` | `3.3.0-alpha1-compatible-918b8c0` | amd64 | unsigned |
| `mina-logproc` | `3.3.0-beta1-dkijania-berkeley-automode-05a597d` | amd64 | unsigned |
| `mina-archive-devnet` | `3.3.0-8c0c2e6` | arm64 | signed |

Each fixture is about 1 KB, against 260 MB for the real packages they replace.
They contain no Mina code, but they are not empty shells: the daemon-shaped
fixture ships a stub `mina` binary that reports a commit hash and a matching
`/var/lib/coda/config_<hash>.json`, which is exactly the pair that
`scripts/verify/check-daemon.sh` compares. That check therefore runs for real.

The limit of the approach: the fixtures declare no dependencies, so the tests do
not exercise dependency resolution or any real Mina binary. They test the
release manager, not the packages.

**Docker Images:**

The test suite uses the following Docker image for promotion tests:

- **Source**: `minaprotocol/mina-daemon:3.3.0-8c0c2e6-bookworm-mainnet-arm64` (Docker Hub)
  - This is a publicly available image that always exists
  - Architecture: arm64
  - Platform: linux/arm64

This image will be pulled from Docker Hub and promoted to the GCP Artifact Registry test repository with a random tag.

## Running Tests Locally

### Prerequisites

Before running the tests, ensure you have the following installed:

1. **deb-s3**: Ruby gem for Debian repository management
   ```bash
   gem install deb-s3
   ```

2. **AWS CLI**: For S3 operations
   ```bash
   # Install via package manager or pip
   pip install awscli
   ```

3. **Docker** (required): runs the mock repository and every verification
   container.
   ```bash
   # On Ubuntu/Debian:
   sudo apt-get update && sudo apt-get install docker.io
   docker ps
   ```

4. **dpkg-deb, gpg, curl** (required): build the fixture packages, make the
   throwaway signing key, and poll the mock for readiness.
   ```bash
   sudo apt-get install dpkg-dev gnupg curl
   ```

   **No AWS credentials are needed.** `mock_repo_start` sets its own against
   MinIO. **No production signing key is needed** either: the signed repository
   is signed with a key generated for the run and deleted afterwards.

5. **Docker Hub / Google Cloud SDK** (optional, for the Docker promotion test
   only - it is the one test that still uses real registries):
   ```bash
   # Install Docker
   # On Ubuntu/Debian:
   sudo apt-get update && sudo apt-get install docker.io

   # On macOS:
   brew install docker

   # Verify Docker is running
   docker --version
   docker ps
   ```

6. **Google Cloud SDK** (optional, for GCP Artifact Registry tests):
   ```bash
   # Install gcloud SDK
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL

   # Authenticate
   gcloud auth login

   # Configure Docker for GCP Artifact Registry
   gcloud auth configure-docker europe-west3-docker.pkg.dev
   ```

   Note: Docker promotion tests will be skipped if Docker or gcloud are not available or not authenticated.

### Running the Tests

```bash
# From the repository root
./buildkite/scripts/tests/release-manager-test.sh
```

### Expected Output

The test script will output:
- Colored status messages (green for info, red for errors, yellow for warnings)
- Test results with ✅ for passed tests and ❌ for failed tests
- A summary at the end showing total tests, passed, and failed counts

Example:
```
[INFO] Starting Release Manager Test Suite
[INFO] Test bucket (unsigned): test-packages
[INFO] Test bucket (signed): signed-test-packages
[INFO] Test region: us-west-2
[INFO] Test codename: bookworm
[INFO] Random suffix: test-1736789012-12345
[mock-repo] starting MinIO container mina-release-mock-repo-141860
[mock-repo] MinIO healthy at http://127.0.0.1:32768
[mock-repo] signing key A5C5017843D320100901B293E53DE1B629F63C3D
[mock-repo] seeded bookworm/ci
...
[INFO] ✅ TEST PASSED: List packages in test repository
[INFO] ✅ TEST PASSED: mina-devnet test package exists
[INFO] ✅ TEST PASSED: Manager verify command dry-run
[INFO] Using random target version: 3.3.0-alpha1-test-1736789012-12345
[INFO] ✅ TEST PASSED: Manager promote command (unsigned, dry-run)
[INFO] Using signing key: A5C5017843D320100901B293E53DE1B629F63C3D
[INFO] ✅ TEST PASSED: Manager promote command (signed, dry-run)
[INFO] ✅ TEST PASSED: Manager publish command (signed, dry-run)

[INFO] =========================================
[INFO] STARTING NON-DRY-RUN TESTS
[INFO] These tests will make actual changes!
[INFO] =========================================

[WARN] This test will actually promote packages to the test repository
[INFO] Using random target version: 3.3.0-alpha1-test-1736789012-12345-real
[INFO] ✓ Promoted package verified in repository
[INFO] ✅ TEST PASSED: Manager promote command (unsigned, real)

[WARN] This test will actually promote packages to the signed test repository
[INFO] ✓ Promoted package verified in signed repository
[INFO] ✅ TEST PASSED: Manager promote command (signed, real)

[WARN] This test will actually pull and push Docker images
[INFO] Source: minaprotocol/mina-daemon:3.3.0-8c0c2e6-bookworm-mainnet-arm64
[INFO] Target: europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-daemon:test-1736789012-12345
[INFO] Pulling source image from Docker Hub...
[INFO] Tagging image for GCP Artifact Registry...
[INFO] Pushing image to GCP Artifact Registry...
[INFO] ✓ Docker image successfully promoted to GCP Artifact Registry
[INFO] ✓ Image verified in GCP Artifact Registry
[INFO] ✅ TEST PASSED: Docker promote to GCP Artifact Registry

[INFO] =========================================
[INFO] TEST SUMMARY
[INFO] =========================================
[INFO] Total tests:  9
[INFO] Passed:       9
[INFO] Failed:       0
[INFO] =========================================
[INFO] 🎉 All tests passed!
```

## CI Integration

### Buildkite Configuration

**Location**: `buildkite/src/Jobs/Test/ReleaseManagerTest.dhall`

The test is automatically run in CI when changes are detected in:
- `buildkite/scripts/release/**` - Release manager scripts
- `scripts/debian/**` - Debian helper scripts
- `scripts/docker/**` - Docker helper scripts
- `buildkite/src/Jobs/Test/ReleaseManagerTest.dhall` - The CI configuration itself
- `buildkite/scripts/tests/release-manager-test.sh` - The test script

### CI Job Configuration

- **Job Name**: ReleaseManagerTest
- **Job Key**: `release-manager-tests`
- **Target Size**: Small
- **Tags**: Fast, Test, Stable, Release
- **Artifacts**: Log files (`*.log`)

### Environment Variables

The Debian tests need none. The mock sets its own credentials and exports the
variables the release scripts read:

| Variable | Set by | Meaning |
|---|---|---|
| `DEB_S3_ENDPOINT` | `mock_repo_start` | Redirects every `deb-s3` call at the mock. Unset in production, where the arguments are exactly what they were before. |
| `DEB_S3_REGION` | `mock_repo_start` | Region claimed in those calls (default `us-west-2`). |
| `MINA_VERIFY_DOCKER_NETWORK` | `mock_repo_start` | Docker network that `scripts/debian/verify.sh` attaches its containers to. |

`DEB_S3_ENDPOINT` is honoured by `scripts/debian/deb-s3-common.sh`, which both
`manager.sh` and `scripts/debian/publish.sh` source. It is the only hook the
production code needed for this; when it is unset, behaviour is unchanged.

The Docker promotion test still needs a Docker Hub pull and a `gcloud`
authentication, and skips itself when they are absent.

## Test Repository Setup

There is none to do. `mock_repo_start` (in `mock-repo.sh`) performs the whole
setup at the start of every run and `mock_repo_stop` removes it afterwards,
from the `EXIT` trap, so an interrupted run cleans up too:

1. Create a docker network and start MinIO on an ephemeral loopback port.
2. Wait for `/minio/health/live`, for at most 60 seconds.
3. Create `test-packages` and `signed-test-packages`, each with an anonymous
   read policy so that `apt` can fetch without credentials.
4. Generate the throwaway signing key and upload its public half to
   `signed-test-packages/repo-signing-key.gpg`, which is where
   `setup.sh` looks for it.
5. Build the fixture packages and upload them into `bookworm/ci`, signing the
   ones that go to the signed repository.

### Inspecting the mock while a test runs

The container name is `mina-release-mock-repo-<pid>`. To look inside it from
another shell during a run:

```bash
export AWS_ACCESS_KEY_ID=minioadmin AWS_SECRET_ACCESS_KEY=minioadmin
ENDPOINT="http://127.0.0.1:$(docker port mina-release-mock-repo-<pid> 9000/tcp | head -1 | sed 's/.*://')"

aws --endpoint-url "$ENDPOINT" s3 ls s3://test-packages/dists/bookworm/

deb-s3 list \
  --bucket test-packages \
  --endpoint "$ENDPOINT" \
  --force-path-style \
  --s3-region us-west-2 \
  --codename bookworm \
  --component ci \
  --arch amd64
```

### Adding a fixture package

Add a call to `_mock_repo_build_deb` in `mock_repo_start`, then upload it with
`_mock_repo_deb_s3 upload`. `_mock_repo_build_deb` decides the payload from the
package name: `mina-logproc` gets a marker binary, `mina-archive*` gets a stub
archive binary, and anything else is treated as daemon-shaped and gets the stub
`mina` plus its matching genesis config.

### Pointing the tests at a real repository

Set `DEB_S3_ENDPOINT` yourself before the suite runs and the release scripts
will use it instead. Leaving it unset makes them talk to AWS, which is what
production does. Note that the test scripts themselves still address the bucket
names in `lib.sh`, so a real run needs those changed as well.

## Extending the Tests

### Adding New Test Cases

To add a new test case:

1. **Create a test function** in `release-manager-test.sh`:
   ```bash
   test_my_new_feature() {
       log_info "========================================="
       log_info "TEST N: Description of test"
       log_info "========================================="

       # Your test logic here
       if [[ condition ]]; then
           assert_success "Test description" 0
       else
           assert_success "Test description" 1
       fi
   }
   ```

2. **Call the test function** in the `main()` function:
   ```bash
   main() {
       # ... existing tests ...
       test_my_new_feature
       # ...
   }
   ```

### Test Helper Functions

The test script provides several helper functions:

- `log_info <message>`: Log informational message in green
- `log_error <message>`: Log error message in red
- `log_warn <message>`: Log warning message in yellow
- `assert_success <test_name> <exit_code>`: Assert command succeeded (exit_code=0)
- `assert_package_exists <test_name> <package> <version> <codename> <component> <bucket> <arch>`: Assert package exists in repository

## Safety Features

The test suite is designed with safety in mind:

1. **Mocked Repositories**: The Debian tests cannot reach any real repository.
   Both buckets live in a MinIO container that exists only for the run, so a
   mistake in the release manager cannot damage a published repository, and a
   test cannot be broken by one.
   - `test-packages` for unsigned packages (in the mock)
   - `signed-test-packages` for signed packages (in the mock)
   - `europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo` for Docker
     images - this one **is** a real registry, used by the Docker promotion
     test only
2. **Random Suffixes**: All promote operations use unique random suffixes to avoid conflicts
3. **Dry-run Tests First**: Tests run dry-run operations before non-dry-run ones
4. **Graceful Skipping**: Tests automatically skip if required tools are not available:
   - Docker tests skip if Docker is not installed
   - GCP tests skip if gcloud is not authenticated
5. **Isolated Environment**: Uses temporary directory for test artifacts
6. **Cleanup**: Automatic cleanup of temporary files and Docker images on exit
7. **Verification**: Non-dry-run tests verify promoted packages actually exist after promotion
8. **Clear Warnings**: Tests that make actual changes display prominent warnings

## Troubleshooting

### Common Issues

1. **"deb-s3 not found"**:
   - Solution: Install deb-s3 with `gem install deb-s3`

2. **"MinIO did not become healthy within 60s"**:
   - The mock repository failed to start. The container logs are printed after
     the message.
   - Check that docker can pull
     `quay.io/minio/minio:RELEASE.2025-02-28T09-55-16Z`, or point
     `MOCK_REPO_IMAGE` at a mirror.
   - The image comes from **quay.io, not Docker Hub**. MinIO no longer
     publishes a publicly pullable `minio/minio` on Docker Hub, so an agent
     without Docker Hub credentials fails with `pull access denied ... may
     require 'docker login'`.

3. **"Package not found" errors**:
   - The fixture seeding failed, or a test asked for a version the mock was
     never seeded with.
   - See **Inspecting the mock while a test runs** above to list what is
     actually there.

4. **"Certificate verification failed" from apt**:
   - This should no longer be possible for the mock, which is plain HTTP. If it
     appears, the repository URL reaching `setup.sh` has a `https://` scheme,
     so check what `TEST_BUCKET_EXTERNAL_URL` was set to.

5. **"Manager script not found"**:
   - Solution: Ensure you're running the test from the repository root or the script can find the manager
   - Check path: `buildkite/scripts/release/manager.sh`

5. **"Docker not found" or Docker tests skipped**:
   - Solution: Install Docker and ensure it's running
   - Check: `docker --version && docker ps`

6. **"GCloud not authenticated" or GCP tests skipped**:
   - Solution: Authenticate with gcloud and configure Docker
   - Run: `gcloud auth login && gcloud auth configure-docker europe-west3-docker.pkg.dev`

7. **"GPG signing key not found" or signed tests skipped**:
   - Solution: Import the Debian signing key
   - Run: `gcloud secrets versions access latest --secret="o1labsDebianRepoKey" | gpg --import`

8. **Docker pull/push failures**:
   - Solution: Check Docker Hub and GCP Artifact Registry access
   - Verify: Can you manually pull `docker pull minaprotocol/mina-daemon:3.3.0-8c0c2e6-bookworm-mainnet-arm64`
   - Verify: Are you authenticated to GCP Artifact Registry?

9. **Non-dry-run test failures**:
   - Check AWS credentials have write permissions to test buckets
   - Check GPG key is correctly imported for signed operations
   - Check network connectivity to S3 and Docker registries

### Debug Mode

To enable verbose output for debugging:

```bash
# Run with bash debug mode
bash -x ./buildkite/scripts/tests/release-manager-test.sh
```

## Future Improvements

Potential enhancements for the test suite:

1. ✅ **Full Integration Tests**: Tests that actually publish/promote (IMPLEMENTED)
   - Non-dry-run Debian promote tests for unsigned and signed repositories
   - Docker promotion test from Docker Hub to GCP Artifact Registry
2. ✅ **Docker Tests**: Add tests for Docker image publishing and promotion (IMPLEMENTED)
   - Docker promotion test pulls from Docker Hub and pushes to GCP Artifact Registry
3. **Multi-architecture Tests**: Test additional architectures
   - Currently tests amd64 for Debian packages and arm64 for Docker images
   - Could add more comprehensive multi-arch testing
4. **End-to-End Verification**: After promote/publish, verify packages are actually installable
   - Use Docker containers to test apt-get install
   - Verify Docker images can actually run
5. **Performance Tests**: Measure and track performance of operations
   - Track time taken for promote/publish operations
   - Monitor package size and upload speeds
6. **Rollback Tests**: Test rollback and recovery scenarios
   - Test removing promoted packages
   - Test re-promoting with different versions
7. **Concurrent Operation Tests**: Test behavior with concurrent publish/promote operations
   - Ensure locking mechanisms work correctly
8. **Manager Script Docker Tests**: Use the manager.sh script for Docker operations
   - Currently using direct docker commands
   - Could test manager.sh Docker promotion features
9. **Multiple Codename Tests**: Test promotion across different Debian codenames
   - Currently focused on bookworm
   - Could test focal, noble, jammy, bullseye. The mock makes this cheap: the
     codename is only a path inside MinIO, and the verification container image
     follows from it.
10. **Dependency resolution**: The fixture packages declare no dependencies, so
    nothing tests that a published package can actually be satisfied. A fixture
    with a `Depends:` line on a real distribution package would cover it.

## Contributing

When modifying the release manager or its tests:

1. Update tests to cover new functionality
2. Run tests locally before submitting PR
3. Update this documentation if adding new test features
4. Ensure all tests pass in CI before merging

## Related Documentation

- [Release Manager README](../release/README.md) - Main release manager documentation
- [Debian Repository Documentation](../../CLAUDE.md) - Debian repository information
- [Buildkite CI Configuration](../../src/README.md) - CI pipeline documentation

## Contact

For questions or issues with the release manager tests, please:
1. Check the troubleshooting section above
2. Review the main release manager documentation
3. Open an issue on the GitHub repository
