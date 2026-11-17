#!/bin/bash

# Unit tests for monorepo.sh
# Usage: ./test_monorepo.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_SCRIPT="$SCRIPT_DIR/monorepo.sh"

# Test temp directory
TEST_DIR=""

# Setup function
setup() {
  TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/jobs"
  mkdir -p "$TEST_DIR/.git"
  echo "test content" > "$TEST_DIR/git_diff.txt"
}



# Teardown function
teardown() {
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Assert functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Expected: ${GREEN}$expected${NC}"
    echo -e "  Actual:   ${RED}$actual${NC}"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -aqF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Expected to find: ${GREEN}$needle${NC}"
    echo -e "  In: ${RED}$haystack${NC}"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! echo "$haystack" | grep -qF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Expected NOT to find: ${RED}$needle${NC}"
    echo -e "  In: $haystack"
    return 1
  fi
}

# Source the functions from monorepo_lib.sh for unit testing
source_monorepo_functions() {
  source "$SCRIPT_DIR/monorepo_lib.sh"
}

# Test: has_matching_tags with filter_any mode
test_has_matching_tags_any() {
  echo -e "\n${YELLOW}Testing: has_matching_tags (any mode)${NC}"

  local tags="- 'Lint'
- 'Stable'
- 'Mesa'"

  # Test matching one tag
  local result
  result=$(has_matching_tags "$tags" true false "lint")
  assert_equals "1" "$result" "Should match when one tag matches (any mode)"

  result=$(has_matching_tags "$tags" true false "stable")
  assert_equals "1" "$result" "Should match case-insensitive (any mode)"

  result=$(has_matching_tags "$tags" true false "unknown")
  assert_equals "0" "$result" "Should not match when no tags match (any mode)"

  result=$(has_matching_tags "$tags" true false "lint" "unknown")
  assert_equals "1" "$result" "Should match when at least one tag matches (any mode)"
}

# Test: has_matching_tags with filter_all mode
test_has_matching_tags_all() {
  echo -e "\n${YELLOW}Testing: has_matching_tags (all mode)${NC}"

  local tags="- 'Lint'
- 'Stable'
- 'Mesa'"

  local result
  result=$(has_matching_tags "$tags" false true "lint" "stable")
  assert_equals "1" "$result" "Should match when all tags match (all mode)"

  result=$(has_matching_tags "$tags" false true "lint" "unknown")
  assert_equals "0" "$result" "Should not match when not all tags match (all mode)"

  result=$(has_matching_tags "$tags" false true "lint" "stable" "mesa")
  assert_equals "1" "$result" "Should match case-insensitive all tags (all mode)"
}

# Test: scope_matches
test_scope_matches() {
  echo -e "\n${YELLOW}Testing: scope_matches${NC}"

  local scope="- 'PullRequest'
- 'Nightly'
- 'MainlineNightly'"

  local result
  result=$(scope_matches "$scope" "pullrequest")
  assert_equals "1" "$result" "Should match scope case-insensitive"

  result=$(scope_matches "$scope" "nightly")
  assert_equals "1" "$result" "Should match scope 'nightly'"

  result=$(scope_matches "$scope" "release")
  assert_equals "0" "$result" "Should not match when scope not present"

  result=$(scope_matches "$scope" "pullrequest" "release")
  assert_equals "1" "$result" "Should match when at least one scope matches"
}

# Test: select_job with full selection
test_select_job_full() {
  echo -e "\n${YELLOW}Testing: select_job (full mode)${NC}"

  local result
  result=$(select_job true false "/tmp/test.yml" "TestJob" "/tmp/diff.txt")
  assert_equals "1" "$result" "Should select all jobs in full mode"
}

# Test: select_job with triaged selection
test_select_job_triaged() {
  echo -e "\n${YELLOW}Testing: select_job (triaged mode)${NC}"

  # Create test files
  cat > "$TEST_DIR/TestJob.yml" << 'EOF'
spec:
  name: TestJob
EOF

  # Test when dirty pattern matches
  echo "^src/.*\.rs$" > "$TEST_DIR/TestJob.dirtywhen"
  echo "src/main.rs" > "$TEST_DIR/diff_match.txt"

  local result
  result=$(select_job false true "$TEST_DIR/TestJob.yml" "TestJob" "$TEST_DIR/diff_match.txt")
  assert_equals "1" "$result" "Should select job when dirty pattern matches"

  # Test when dirty pattern doesn't match
  echo "docs/README.md" > "$TEST_DIR/diff_nomatch.txt"
  result=$(select_job false true "$TEST_DIR/TestJob.yml" "TestJob" "$TEST_DIR/diff_nomatch.txt")
  assert_equals "0" "$result" "Should not select job when dirty pattern doesn't match"
}

# Test: Integration test - full script execution
test_integration_full_selection() {
  echo -e "\n${YELLOW}Testing: Integration - full selection${NC}"

  cat > "$TEST_DIR/jobs/IntegrationTest.yml" << 'EOF'
spec:
  name: IntegrationTest
  path: Test
  tags:
    - Lint
  scope:
    - PullRequest
EOF
  echo "^.*$" > "$TEST_DIR/jobs/IntegrationTest.dirtywhen"

  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags lint \
    --filter-mode any \
    --selection-mode full \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/git_diff.txt" \
    --dry-run 2>&1 || true)

  assert_contains "$output" "Including job IntegrationTest" "Should include matching job"
  assert_contains "$output" "Dry run enabled" "Should show dry run message"
}

# Test: Integration test - tag filtering
test_integration_tag_filtering() {
  echo -e "\n${YELLOW}Testing: Integration - tag filtering${NC}"

  cat > "$TEST_DIR/jobs/TagFilterTest.yml" << 'EOF'
spec:
  name: TagFilterTest
  path: Test
  tags:
    - Build
  scope:
    - PullRequest
EOF
  echo "^.*$" > "$TEST_DIR/jobs/TagFilterTest.dirtywhen"

  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags lint \
    --filter-mode any \
    --selection-mode full \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/git_diff.txt" \
    --dry-run 2>&1 || true)

  assert_contains "$output" "rejected job due to tags mismatch" "Should reject job with non-matching tags"
}

# Test: Integration test - scope filtering
test_integration_scope_filtering() {
  echo -e "\n${YELLOW}Testing: Integration - scope filtering${NC}"

  cat > "$TEST_DIR/jobs/ScopeFilterTest.yml" << 'EOF'
spec:
  name: ScopeFilterTest
  path: Test
  tags:
    - Lint
  scope:
    - Release
EOF
  echo "^.*$" > "$TEST_DIR/jobs/ScopeFilterTest.dirtywhen"

  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags lint \
    --filter-mode any \
    --selection-mode full \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/git_diff.txt" \
    --dry-run 2>&1 || true)

  assert_contains "$output" "rejected job due to scope mismatch" "Should reject job with non-matching scope"
}

# Test: Integration test - dependency resolution
# A job selected by dirty-when must pull in the build jobs it depends on, even
# when those builds' own dirty-when did not match the change set. This is the
# case that used to break: modifying a bench file triggers the bench but not the
# apps/package build it needs.
test_integration_dependency_resolution() {
  echo -e "\n${YELLOW}Testing: Integration - dependency resolution${NC}"

  # Bench job: selected by dirty-when, depends on a build job's package step.
  cat > "$TEST_DIR/jobs/DepBench.yml" << 'EOF'
spec:
  name: DepBench
  path: Bench
  tags:
    - DepTest
  scope:
    - PullRequest
pipeline:
  steps:
    - key: dep-bench-run
      depends_on:
        - step: _DepBuild-build-deb-pkg
EOF
  echo "bench" > "$TEST_DIR/jobs/DepBench.dirtywhen"

  # Package build: dirty-when does NOT match the bench change; depends on apps.
  cat > "$TEST_DIR/jobs/DepBuild.yml" << 'EOF'
spec:
  name: DepBuild
  path: Release
  tags:
    - DepTest
  scope:
    - PullRequest
pipeline:
  steps:
    - key: _DepBuild-build-deb-pkg
      depends_on:
        - step: _DepBuildApps-build-apps
EOF
  echo "^src/" > "$TEST_DIR/jobs/DepBuild.dirtywhen"

  # Apps build: transitive dependency, also not matched by the change.
  cat > "$TEST_DIR/jobs/DepBuildApps.yml" << 'EOF'
spec:
  name: DepBuildApps
  path: Release
  tags:
    - DepTest
  scope:
    - PullRequest
pipeline:
  steps:
    - key: _DepBuildApps-build-apps
EOF
  echo "^src/" > "$TEST_DIR/jobs/DepBuildApps.dirtywhen"

  # Change set touches only a bench file: matches DepBench, not the builds.
  echo "buildkite/scripts/bench/run.sh" > "$TEST_DIR/dep_diff.txt"

  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags deptest \
    --filter-mode any \
    --selection-mode triaged \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/dep_diff.txt" \
    --dry-run 2>&1 || true)

  assert_contains "$output" "Including job DepBench" "Bench job selected by dirty-when"
  assert_contains "$output" "Including dependency job DepBuild" "Package build pulled in as a dependency"
  assert_contains "$output" "Including dependency job DepBuildApps" "Transitive apps build pulled in"
  assert_contains "$output" "skipping upload for job: DepBuild" "Dependency build is in the upload set"
  assert_contains "$output" "skipping upload for job: DepBuildApps" "Transitive dependency is in the upload set"
}

# Test: Integration test - dependency deduplication
# When two selected jobs share a dependency, that dependency is uploaded once.
test_integration_dependency_dedup() {
  echo -e "\n${YELLOW}Testing: Integration - dependency dedup (no duplicate uploads)${NC}"

  # Second bench that also depends on the same DepBuild package step.
  cat > "$TEST_DIR/jobs/DepBench2.yml" << 'EOF'
spec:
  name: DepBench2
  path: Bench
  tags:
    - DepTest
  scope:
    - PullRequest
pipeline:
  steps:
    - key: dep-bench2-run
      depends_on:
        - step: _DepBuild-build-deb-pkg
EOF
  echo "bench" > "$TEST_DIR/jobs/DepBench2.dirtywhen"

  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags deptest \
    --filter-mode any \
    --selection-mode triaged \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/dep_diff.txt" \
    --dry-run 2>&1 || true)

  # DepBuild is a shared dependency of DepBench and DepBench2, uploaded once.
  local build_uploads
  build_uploads=$(echo "$output" | grep -c "skipping upload for job: DepBuild$" || true)
  assert_equals "1" "$build_uploads" "Shared dependency DepBuild uploaded exactly once"
}

# Test: Integration test - dependency NOT pulled when it is selectable on its own.
# In full mode (and in multi-phase runs generally) a dependency is uploaded by
# its own triage step, so pulling it here would duplicate the step key. Only
# dependencies that triage would reject (e.g. dirty-when miss) should be pulled.
test_integration_dependency_skip_when_selectable() {
  echo -e "\n${YELLOW}Testing: Integration - dependency not pulled when selectable${NC}"

  # A test that depends on a build carrying a different tag (its own "phase").
  cat > "$TEST_DIR/jobs/FullDepTest.yml" << 'EOF'
spec:
  name: FullDepTest
  path: Test
  tags:
    - FullDep
  scope:
    - PullRequest
pipeline:
  steps:
    - key: full-dep-test-run
      depends_on:
        - step: _FullDepBuild-build-deb-pkg
EOF
  echo "^.*$" > "$TEST_DIR/jobs/FullDepTest.dirtywhen"

  cat > "$TEST_DIR/jobs/FullDepBuild.yml" << 'EOF'
spec:
  name: FullDepBuild
  path: Release
  tags:
    - BuildOnly
  scope:
    - PullRequest
pipeline:
  steps:
    - key: _FullDepBuild-build-deb-pkg
EOF
  echo "^.*$" > "$TEST_DIR/jobs/FullDepBuild.dirtywhen"

  # Full selection: every job is selected on its own, so the build is uploaded
  # by its own step and must NOT be pulled as a dependency.
  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags fulldep \
    --filter-mode any \
    --selection-mode full \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/git_diff.txt" \
    --dry-run 2>&1 || true)

  assert_contains "$output" "Including job FullDepTest" "Dependent test is selected"
  assert_not_contains "$output" "Including dependency job FullDepBuild" "Selectable build is NOT pulled as a dependency"
}

# Main test runner
main() {
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}Running monorepo.sh Unit Tests${NC}"
  echo -e "${YELLOW}========================================${NC}"

  # Check if monorepo.sh exists
  if [[ ! -f "$MONOREPO_SCRIPT" ]]; then
    echo -e "${RED}Error: monorepo.sh not found at $MONOREPO_SCRIPT${NC}"
    exit 1
  fi

  # Check for required tools
  for tool in yq git; do
    if ! command -v "$tool" &> /dev/null; then
      echo -e "${RED}Error: Required tool '$tool' is not installed${NC}"
      exit 1
    fi
  done

  setup

  # Source functions for unit testing
  source_monorepo_functions

  # Run unit tests
  test_has_matching_tags_any
  test_has_matching_tags_all
  test_scope_matches
  test_select_job_full
  test_select_job_triaged

  # Run integration tests
  test_integration_full_selection
  test_integration_tag_filtering
  test_integration_scope_filtering
  test_integration_dependency_resolution
  test_integration_dependency_dedup
  test_integration_dependency_skip_when_selectable

  teardown

  # Print summary
  echo -e "\n${YELLOW}========================================${NC}"
  echo -e "${YELLOW}Test Summary${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo -e "Tests run:    $TESTS_RUN"
  echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    exit 1
  else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  fi
}

# Run tests
main "$@"
