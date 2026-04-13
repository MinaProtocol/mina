#!/usr/bin/env bash

# Update GAR Cleanup Policy Whitelist
#
# Creates a PR to gitops-infrastructure adding the release tag prefix
# to the gcr.io "Keep protected mina releases" KEEP policy.
# This protects release Docker images from automatic cleanup deletion.
#
# Designed to run as a post-promotion step in the promoter pipeline.
# On non-release branches, exits cleanly (no-op for nightly promotions).
#
# Prerequisites:
#   - GITTAG and GITHASH exported (via export-git-env-vars.sh)
#   - GITHUB_TOKEN or GH_TOKEN set for GitHub API access
#   - gh CLI available
#
# Optional env vars:
#   - GAR_TAG_PREFIX: override the tag prefix (default: GITTAG-GITHASH)
#   - DRY_RUN=1: print what would be done without making changes

set -euo pipefail

# Guard: only run on release branches.
# The promoter pipeline handles both nightly and release promotions.
# GAR whitelist updates are only needed for releases — nightly images
# are protected by "keep recent N versions" policies and have short lifetimes.
BRANCH="${BUILDKITE_BRANCH:-unknown}"
if [[ ! "${BRANCH}" =~ ^release/ ]]; then
    echo "⏭️  Skipping GAR whitelist update (branch '${BRANCH}' is not a release branch)"
    exit 0
fi

# Compute release tag prefix.
# Default: GITTAG-GITHASH (e.g., 3.4.0-alpha1-22d9374).
# This prefix protects all codename/network variants via GAR prefix matching.
TAG_PREFIX="${GAR_TAG_PREFIX:-${GITTAG}-${GITHASH}}"

GITOPS_REPO="o1-labs/gitops-infrastructure"
TFVARS_PATH="platform/gcloud/artifact-registry/registries.tfvars"
BRANCH_NAME="auto/gar-whitelist-${TAG_PREFIX}"

echo "🏷️  Release tag prefix: ${TAG_PREFIX}"
echo "📦 Target: ${GITOPS_REPO} / ${TFVARS_PATH}"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY RUN] Would create PR to add '${TAG_PREFIX}' to GAR whitelist"
    exit 0
fi

# Check prerequisites
if ! command -v gh &>/dev/null; then
    echo "❌ gh CLI not found. Skipping GAR whitelist update."
    echo "   Install gh CLI or set GITHUB_TOKEN to enable this step."
    exit 0
fi

if [[ -z "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
    echo "⚠️  GITHUB_TOKEN or GH_TOKEN not set. Skipping GAR whitelist update."
    echo "   Set one of these env vars to enable automated whitelist PRs."
    exit 0
fi

# Idempotency: skip if PR already exists for this tag
if gh pr list --repo "${GITOPS_REPO}" --head "${BRANCH_NAME}" --state open --json number 2>/dev/null | grep -q "number"; then
    echo "✅ PR already exists for ${TAG_PREFIX}, skipping."
    exit 0
fi

# Clone, modify, create PR
WORKDIR=$(mktemp -d)
trap 'rm -rf "${WORKDIR}"' EXIT

echo "📥 Cloning ${GITOPS_REPO}..."
gh repo clone "${GITOPS_REPO}" "${WORKDIR}" -- --depth 1 -q

cd "${WORKDIR}"
git config user.email "mina-promoter-pipeline@o1labs.org"
git config user.name "Mina Promoter Pipeline"
gh auth setup-git 2>/dev/null || true
git checkout -b "${BRANCH_NAME}"

# Insert tag prefix into gcr.io "Keep protected mina releases" tag_prefixes list
echo "📝 Inserting '${TAG_PREFIX}' into GAR whitelist..."
python3 -c "
import re
import sys

tfvars_path = '${TFVARS_PATH}'
tag_prefix = '${TAG_PREFIX}'

with open(tfvars_path, 'r') as f:
    content = f.read()

quoted_tag = '\"' + tag_prefix + '\"'

# Find the 'Keep protected mina releases' policy block's tag_prefixes list
# Pattern: locate the policy by name, then find tag_prefixes = [ ... ]
pattern = r'(\"Keep protected mina releases\".*?tag_prefixes\s*=\s*\[)(.*?)(\])'
match = re.search(pattern, content, re.DOTALL)

if not match:
    print('Could not find \"Keep protected mina releases\" tag_prefixes block')
    print('The registries.tfvars structure may have changed — update the pattern.')
    sys.exit(1)

if quoted_tag in match.group(2):
    print(f'{quoted_tag} already in whitelist, no changes needed')
    sys.exit(0)

# Insert before the closing ]
existing = match.group(2).rstrip()
if existing.endswith('\"'):
    new_content = existing + ',\n            ' + quoted_tag
else:
    new_content = existing + '\n            ' + quoted_tag

content = content[:match.start(2)] + new_content + '\n          ' + content[match.end(2):]

with open(tfvars_path, 'w') as f:
    f.write(content)

print(f'Added {quoted_tag} to gcr.io whitelist')
"

# Check if any changes were made
if git diff --quiet "${TFVARS_PATH}" 2>/dev/null; then
    echo "✅ No changes needed (tag already whitelisted)."
    exit 0
fi

# Commit and push
git add "${TFVARS_PATH}"
git commit -m "auto: Add GAR whitelist entry for release ${TAG_PREFIX}"
git push origin "${BRANCH_NAME}"

# Create PR
echo "🔀 Creating PR..."
gh pr create \
    --repo "${GITOPS_REPO}" \
    --title "Add GAR whitelist for release ${TAG_PREFIX}" \
    --body "$(cat <<EOF
Automated PR from Mina promoter pipeline.

**Build**: ${BUILDKITE_BUILD_URL:-unknown}
**Branch**: ${BRANCH}
**Tag prefix**: \`${TAG_PREFIX}\`

Adds \`${TAG_PREFIX}\` to the KEEP policy \`tag_prefixes\` for the \`gcr.io\` registry
in \`${TFVARS_PATH}\`.

This protects release Docker images from automatic cleanup deletion by the
GAR cleanup policies. The prefix covers all codename/network/arch variants
(e.g., \`${TAG_PREFIX}-noble-devnet\`, \`${TAG_PREFIX}-bookworm-mainnet\`, etc.).
EOF
)" \
    --base main \
    --head "${BRANCH_NAME}"

echo "✅ GAR whitelist PR created successfully."
