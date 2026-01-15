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

  if echo "$haystack" | grep -q "$needle"; then
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

  if ! echo "$haystack" | grep -q "$needle"; then
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

# Test: check_exclude_if with no excludeIf
test_check_exclude_if_no_conditions() {
  echo -e "\n${YELLOW}Testing: check_exclude_if (no conditions)${NC}"

  cat > "$TEST_DIR/NoExclude.yml" << 'EOF'
spec:
  name: NoExclude
  tags: [Lint]
  scope: [PullRequest]
EOF

  local result
  result=$(check_exclude_if "$TEST_DIR/NoExclude.yml" "NoExclude" "mesa" 2>/dev/null)
  assert_equals "0" "$result" "Should not exclude when no excludeIf present"
}

# Test: check_exclude_if with matching ancestor
test_check_exclude_if_matching() {
  echo -e "\n${YELLOW}Testing: check_exclude_if (matching ancestor)${NC}"

  cat > "$TEST_DIR/ExcludeMatch.yml" << 'EOF'
spec:
  name: ExcludeMatch
  tags: [Lint]
  scope: [PullRequest]
  excludeIf:
    - ancestor: mesa
      reason: "Test exclusion"
EOF

  local result output
  output=$(check_exclude_if "$TEST_DIR/ExcludeMatch.yml" "ExcludeMatch" "mesa" 2>&1)
  result=$(echo "$output" | tail -1)

  assert_equals "1" "$result" "Should exclude when ancestor matches"
  assert_contains "$output" "excluded based on excludeIf condition" "Should show exclusion message"
}

# Test: check_exclude_if with non-matching ancestor
test_check_exclude_if_not_matching() {
  echo -e "\n${YELLOW}Testing: check_exclude_if (non-matching ancestor)${NC}"

  cat > "$TEST_DIR/ExcludeNoMatch.yml" << 'EOF'
spec:
  name: ExcludeNoMatch
  tags: [Lint]
  scope: [PullRequest]
  excludeIf:
    - ancestor: Develop
      reason: "Test exclusion"
EOF

  local result
  result=$(check_exclude_if "$TEST_DIR/ExcludeNoMatch.yml" "ExcludeNoMatch" "mesa" 2>/dev/null)
  assert_equals "0" "$result" "Should not exclude when ancestor doesn't match"
}

# Test: check_exclude_if with non-ancestor excludeIf items
test_check_exclude_if_skip_non_ancestor() {
  echo -e "\n${YELLOW}Testing: check_exclude_if (skip non-ancestor items)${NC}"

  cat > "$TEST_DIR/ExcludeMixed.yml" << 'EOF'
spec:
  name: ExcludeMixed
  tags: [Lint]
  scope: [PullRequest]
  excludeIf:
    - someOtherField: value
    - ancestor: Compatible
      reason: "Test exclusion"
    - futureType: something
EOF

  local result output
  output=$(check_exclude_if "$TEST_DIR/ExcludeMixed.yml" "ExcludeMixed" "mesa" 2>&1)
  result=$(echo "$output" | tail -1)

  assert_equals "0" "$result" "Should not exclude when no ancestor matches"
  assert_contains "$output" "Skipping excludeIf" "Should show skip messages for non-ancestor items"
}

# Test: check_exclude_if exact case matching
test_check_exclude_if_exact_case() {
  echo -e "\n${YELLOW}Testing: check_exclude_if (exact case matching)${NC}"

  cat > "$TEST_DIR/ExcludeCase.yml" << 'EOF'
spec:
  name: ExcludeCase
  tags: [Lint]
  scope: [PullRequest]
  excludeIf:
    - ancestor: mesa
      reason: "Test exact case"
EOF

  local result
  result=$(check_exclude_if "$TEST_DIR/ExcludeCase.yml" "ExcludeCase" "mesa" 2>/dev/null)
  assert_equals "1" "$result" "Should exclude with exact case matching"

  # Test that different case does NOT match
  result=$(check_exclude_if "$TEST_DIR/ExcludeCase.yml" "ExcludeCase" "MESA" 2>/dev/null)
  assert_equals "0" "$result" "Should NOT exclude when case differs"
}

# Test: check_include_if with no includeIf
test_check_include_if_no_conditions() {
  echo -e "\n${YELLOW}Testing: check_include_if (no conditions)${NC}"

  cat > "$TEST_DIR/NoInclude.yml" << 'EOF'
spec:
  name: NoInclude
  tags: [Lint]
  scope: [PullRequest]
EOF

  local result
  result=$(check_include_if "$TEST_DIR/NoInclude.yml" "NoInclude" "mesa" 2>/dev/null)
  assert_equals "1" "$result" "Should include by default when no includeIf present"
}

# Test: check_include_if with matching ancestor
test_check_include_if_matching() {
  echo -e "\n${YELLOW}Testing: check_include_if (matching ancestor)${NC}"

  cat > "$TEST_DIR/IncludeMatch.yml" << 'EOF'
spec:
  name: IncludeMatch
  tags: [Lint]
  scope: [PullRequest]
  includeIf:
    - ancestor: mesa
      reason: "Only run on mesa descendants"
EOF

  local result output
  output=$(check_include_if "$TEST_DIR/IncludeMatch.yml" "IncludeMatch" "mesa" 2>&1)
  result=$(echo "$output" | tail -1)

  assert_equals "1" "$result" "Should include when ancestor matches"
  assert_contains "$output" "included based on includeIf condition" "Should show inclusion message"
}

# Test: check_include_if with non-matching ancestor
test_check_include_if_not_matching() {
  echo -e "\n${YELLOW}Testing: check_include_if (non-matching ancestor)${NC}"

  cat > "$TEST_DIR/IncludeNoMatch.yml" << 'EOF'
spec:
  name: IncludeNoMatch
  tags: [Lint]
  scope: [PullRequest]
  includeIf:
    - ancestor: Develop
      reason: "Only run on Develop descendants"
EOF

  local result output
  output=$(check_include_if "$TEST_DIR/IncludeNoMatch.yml" "IncludeNoMatch" "mesa" 2>&1)
  result=$(echo "$output" | tail -1)

  assert_equals "0" "$result" "Should exclude when ancestor doesn't match any includeIf condition"
  assert_contains "$output" "none of the includeIf conditions matched" "Should show exclusion message"
}

# Test: check_include_if with multiple conditions (one matches)
test_check_include_if_multiple_one_matches() {
  echo -e "\n${YELLOW}Testing: check_include_if (multiple conditions, one matches)${NC}"

  cat > "$TEST_DIR/IncludeMultiple.yml" << 'EOF'
spec:
  name: IncludeMultiple
  tags: [Lint]
  scope: [PullRequest]
  includeIf:
    - ancestor: develop
      reason: "Run on develop"
    - ancestor: mesa
      reason: "Run on mesa"
    - ancestor: master
      reason: "Run on master"
EOF

  local result
  result=$(check_include_if "$TEST_DIR/IncludeMultiple.yml" "IncludeMultiple" "mesa" 2>/dev/null)
  assert_equals "1" "$result" "Should include when at least one includeIf condition matches"
}

# Test: check_include_if with multiple conditions (none match)
test_check_include_if_multiple_none_match() {
  echo -e "\n${YELLOW}Testing: check_include_if (multiple conditions, none match)${NC}"

  cat > "$TEST_DIR/IncludeNoneMatch.yml" << 'EOF'
spec:
  name: IncludeNoneMatch
  tags: [Lint]
  scope: [PullRequest]
  includeIf:
    - ancestor: develop
      reason: "Run on develop"
    - ancestor: master
      reason: "Run on master"
EOF

  local result
  result=$(check_include_if "$TEST_DIR/IncludeNoneMatch.yml" "IncludeNoneMatch" "mesa" 2>/dev/null)
  assert_equals "0" "$result" "Should exclude when no includeIf conditions match"
}

# Test: check_include_if exact case matching
test_check_include_if_exact_case() {
  echo -e "\n${YELLOW}Testing: check_include_if (exact case matching)${NC}"

  cat > "$TEST_DIR/IncludeCase.yml" << 'EOF'
spec:
  name: IncludeCase
  tags: [Lint]
  scope: [PullRequest]
  includeIf:
    - ancestor: mesa
      reason: "Test exact case"
EOF

  local result
  result=$(check_include_if "$TEST_DIR/IncludeCase.yml" "IncludeCase" "mesa" 2>/dev/null)
  assert_equals "1" "$result" "Should include with exact case matching"

  # Test that different case does NOT match
  result=$(check_include_if "$TEST_DIR/IncludeCase.yml" "IncludeCase" "MESA" 2>/dev/null)
  assert_equals "0" "$result" "Should NOT include when case differs"
}

# Test: check_include_if with non-ancestor includeIf items
test_check_include_if_skip_non_ancestor() {
  echo -e "\n${YELLOW}Testing: check_include_if (skip non-ancestor items)${NC}"

  cat > "$TEST_DIR/IncludeMixed.yml" << 'EOF'
spec:
  name: IncludeMixed
  tags: [Lint]
  scope: [PullRequest]
  includeIf:
    - someOtherField: value
    - ancestor: mesa
      reason: "Run on mesa"
    - futureType: something
EOF

  local result output
  output=$(check_include_if "$TEST_DIR/IncludeMixed.yml" "IncludeMixed" "mesa" 2>&1)
  result=$(echo "$output" | tail -1)

  assert_equals "1" "$result" "Should include when at least one ancestor condition matches"
  assert_contains "$output" "Skipping includeIf" "Should show skip messages for non-ancestor items"
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
    --mainline-branches mesa,master,develop \
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
    --mainline-branches mesa,master,develop \
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
    --mainline-branches mesa,master,develop \
    --dry-run 2>&1 || true)

  assert_contains "$output" "rejected job due to scope mismatch" "Should reject job with non-matching scope"
}

# Test: Integration test - includeIf with non-matching ancestor
test_integration_include_if_not_matching() {
  echo -e "\n${YELLOW}Testing: Integration - includeIf not matching${NC}"

  cat > "$TEST_DIR/jobs/IncludeIfNoMatch.yml" << 'EOF'
spec:
  name: IncludeIfNoMatch
  path: Test
  tags:
    - Lint
  scope:
    - PullRequest
  includeIf:
    - ancestor: nonexistent
      reason: "Only run on Nonexistent descendants"
EOF
  echo "^.*$" > "$TEST_DIR/jobs/IncludeIfNoMatch.dirtywhen"

  local output
  output=$("$MONOREPO_SCRIPT" \
    --scopes pullrequest \
    --tags lint \
    --filter-mode any \
    --selection-mode full \
    --jobs "$TEST_DIR/jobs" \
    --git-diff-file "$TEST_DIR/git_diff.txt" \
    --mainline-branches mesa,master,develop \
    --dry-run 2>&1 || true)

  assert_contains "$output" "none of the includeIf conditions matched" "Should show includeIf exclusion message"
  assert_not_contains "$output" "Including job IncludeIfNoMatch" "Should not include job when includeIf doesn't match"
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
  test_check_exclude_if_no_conditions
  test_check_exclude_if_matching
  test_check_exclude_if_not_matching
  test_check_exclude_if_skip_non_ancestor
  test_check_exclude_if_exact_case
  test_check_include_if_no_conditions
  test_check_include_if_matching
  test_check_include_if_not_matching
  test_check_include_if_multiple_one_matches
  test_check_include_if_multiple_none_match
  test_check_include_if_exact_case
  test_check_include_if_skip_non_ancestor

  # Run integration tests
  test_integration_full_selection
  test_integration_tag_filtering
  test_integration_scope_filtering
  test_integration_include_if_not_matching

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
