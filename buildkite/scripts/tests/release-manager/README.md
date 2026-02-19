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

**Non-dry-run Tests (Actual operations that make changes):**
7. **Manager Promote - Unsigned (Real)**: Actually promotes packages in unsigned test repository with verification
8. **Manager Promote - Signed (Real)**: Actually promotes packages in signed test repository with GPG signing and verification
9. **Docker Promote to GCP**: Pulls Docker image from Docker Hub (`minaprotocol/mina-daemon:3.3.0-8c0c2e6-bookworm-mainnet-arm64`) and pushes to GCP Artifact Registry (`europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-daemon:random-tag`)

### Test Configuration

The tests use the following configuration:

**Unsigned Repository:**
- **Test Bucket**: `test.packages.o1test.net`
- **Test Region**: `us-west-2`
- **Test Codename**: `bullseye`
- **Test Component (CI)**: `ci`
- **Test Component (Promote Target)**: `test`
- **Test Architecture**: `amd64`

**Signed Repository:**
- **Test Bucket**: `signed.test.packages.o1test.net`
- **Test Region**: `us-west-2`
- **Test Codename**: `bullseye`
- **Test Component**: `ci`
- **Signing Key**: `386E9DAC378726A48ED5CE56ADB30D9ACE02F414`
- **Test Architecture**: `amd64`

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

The test suite expects the following packages to be available in the test repository:

1. `mina-devnet_3.3.0-alpha1-compatible-918b8c0_amd64.deb`
2. `mina-logproc_3.3.0-beta1-dkijania-berkeley-automode-05a597d_amd64.deb`

These packages should be uploaded to the `test.packages.o1test.net` bucket in the `bullseye/ci` component.

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

3. **AWS Credentials**: Set up AWS credentials with access to the test buckets
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-west-2"
   ```

4. **GPG Key** (optional, for signed repository non-dry-run tests): Import the Debian signing key
   ```bash
   # Import from Google Cloud Secret Manager (if available)
   gcloud secrets versions access latest --secret="o1labsDebianRepoKey" | gpg --import

   # Verify key is imported (should show key 386E9DAC378726A48ED5CE56ADB30D9ACE02F414)
   gpg --list-secret-keys
   ```

   Note: Signed repository tests will skip non-dry-run operations if the GPG key is not available.

5. **Docker** (optional, for Docker promotion tests):
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
[INFO] Test bucket (unsigned): test.packages.o1test.net
[INFO] Test bucket (signed): signed.test.packages.o1test.net
[INFO] Test region: us-west-2
[INFO] Test codename: bullseye
[INFO] Random suffix: test-1736789012-12345
...
[INFO] ✅ TEST PASSED: List packages in test repository
[INFO] ✅ TEST PASSED: mina-devnet test package exists
[INFO] ✅ TEST PASSED: Manager verify command dry-run
[INFO] Using random target version: 3.3.0-alpha1-test-1736789012-12345
[INFO] ✅ TEST PASSED: Manager promote command (unsigned, dry-run)
[INFO] Using signing key: 386E9DAC378726A48ED5CE56ADB30D9ACE02F414
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

The CI job requires the following environment variables:
- `AWS_ACCESS_KEY_ID`: AWS access key for S3 operations
- `AWS_SECRET_ACCESS_KEY`: AWS secret key for S3 operations
- `AWS_DEFAULT_REGION`: AWS region (set to `us-west-2`)

## Test Repository Setup

### Creating Test Packages

If you need to recreate or update the test packages:

1. **Build or obtain test Debian packages**:
   ```bash
   # Example: Copy existing packages for testing
   cp _build/mina-devnet_*.deb /tmp/test-packages/
   cp _build/mina-logproc_*.deb /tmp/test-packages/
   ```

2. **Upload to test repository**:
   ```bash
   deb-s3 upload \
     --bucket test.packages.o1test.net \
     --s3-region us-west-2 \
     --codename bullseye \
     --component ci \
     --arch amd64 \
     /tmp/test-packages/*.deb
   ```

### Listing Test Packages

To see what packages are in the test repository:

```bash
deb-s3 list \
  --bucket test.packages.o1test.net \
  --s3-region us-west-2 \
  --codename bullseye \
  --component ci \
  --arch amd64
```

### Cleaning Up Test Packages

If you need to remove test packages:

```bash
# Note: deb-s3 doesn't have a direct delete command
# Use AWS CLI to remove files from S3 bucket
aws s3 rm s3://test.packages.o1test.net/pool/... --recursive
```

### Setting Up Signed Test Repository

The tests also use a signed repository at `signed.test.packages.o1test.net`. To set this up:

1. **Create the S3 bucket** (if not exists):
   ```bash
   aws s3 mb s3://signed.test.packages.o1test.net --region us-west-2
   ```

2. **Upload test packages with signing**:
   ```bash
   deb-s3 upload \
     --bucket signed.test.packages.o1test.net \
     --s3-region us-west-2 \
     --codename bullseye \
     --component ci \
     --arch amd64 \
     --sign 386E9DAC378726A48ED5CE56ADB30D9ACE02F414 \
     /tmp/test-packages/*.deb
   ```

3. **Verify signed repository**:
   ```bash
   deb-s3 list \
     --bucket signed.test.packages.o1test.net \
     --s3-region us-west-2 \
     --codename bullseye \
     --component ci
   ```

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
- `assert_package_exists <test_name> <package> <version> <codename> <component>`: Assert package exists in repository

## Safety Features

The test suite is designed with safety in mind:

1. **Test Repositories**: Uses dedicated test repositories, not production
   - `test.packages.o1test.net` for unsigned packages
   - `signed.test.packages.o1test.net` for signed packages
   - `europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo` for Docker images
2. **Random Suffixes**: All promote operations use unique random suffixes to avoid conflicts
3. **Dry-run Tests First**: Tests run dry-run operations before non-dry-run ones
4. **Graceful Skipping**: Tests automatically skip if required tools are not available:
   - Signed promote tests skip if GPG key is not imported
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

2. **"AWS credentials not set"**:
   - Solution: Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables

3. **"Package not found" errors**:
   - Solution: Verify test packages exist in the test repository
   - Run: `deb-s3 list --bucket test.packages.o1test.net --s3-region us-west-2 --codename bullseye --component ci`

4. **"Manager script not found"**:
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
   - Currently focused on bullseye
   - Could test focal, noble, jammy, bookworm

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
