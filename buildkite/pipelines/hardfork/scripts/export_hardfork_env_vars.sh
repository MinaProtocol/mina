#!/bin/bash
# this script is used to set environment variables that are to be used during the Mina network hardfork

set -euo pipefail

echo "--- Importing hard fork parameters"

##########################################################
# Vars for compiling Mina src and .deb packages
##########################################################

export DUNE_PROFILE="devnet"
export BUILDKITE_BRANCH="fix/nonce-test-flake"

##########################################################
# the below values are placeholders that have been copied from: 
# https://buildkite.com/o-1-labs-2/mina-o-1-labs/builds/27933
##########################################################

# export CI="true"
# export BUILDKITE="true"
# export BUILDKITE_ORGANIZATION_SLUG="o-1-labs-2"
# export BUILDKITE_PIPELINE_SLUG="mina-o-1-labs"
# export BUILDKITE_PIPELINE_NAME="Mina O(1)Labs"
# export BUILDKITE_PIPELINE_ID="8f4b7485-ef17-469a-bec2-221aef440bff"
# export BUILDKITE_PIPELINE_PROVIDER="github"
# export BUILDKITE_PIPELINE_DEFAULT_BRANCH="develop"
# export BUILDKITE_REPO="https://github.com/MinaProtocol/mina.git"
# export BUILDKITE_BUILD_ID="01878295-b313-42c0-9958-0a0337e7a844"
# export BUILDKITE_BUILD_NUMBER="27933"
# export BUILDKITE_BUILD_URL="https://buildkite.com/o-1-labs-2/mina-o-1-labs/builds/27933"
# export BUILDKITE_TAG=""
# export BUILDKITE_COMMIT="03514dc3757f9c5a7f865ad07310df964e9d3773"
# export BUILDKITE_MESSAGE="update graphQL schema"
# export BUILDKITE_SOURCE="api"
# export BUILDKITE_BUILD_AUTHOR="deepthiskumar"
# export BUILDKITE_BUILD_AUTHOR_EMAIL=""
# export BUILDKITE_BUILD_CREATOR="Brandon Kase"
# export BUILDKITE_BUILD_CREATOR_EMAIL="brandernan@gmail.com"
# export BUILDKITE_REBUILT_FROM_BUILD_ID=""
# export BUILDKITE_REBUILT_FROM_BUILD_NUMBER=""
# export BUILDKITE_PULL_REQUEST="12961"
# export BUILDKITE_PULL_REQUEST_BASE_BRANCH="berkeley"
# export BUILDKITE_PULL_REQUEST_REPO="https://github.com/MinaProtocol/mina.git"
# export BUILDKITE_TRIGGERED_FROM_BUILD_ID=""
# export BUILDKITE_TRIGGERED_FROM_BUILD_NUMBER=""
# export BUILDKITE_TRIGGERED_FROM_BUILD_PIPELINE_SLUG=""
# export BUILDKITE_JOB_ID="0187917e-fcab-4c27-af66-c5fe04f10407"
# export BUILDKITE_LABEL="Build Mina for Bullseye"
# export BUILDKITE_ARTIFACT_PATHS=""
# export BUILDKITE_RETRY_COUNT="1"
# export BUILDKITE_TIMEOUT="360"
# export BUILDKITE_STEP_KEY="_MinaArtifactBullseye-build-deb-pkg"
# export BUILDKITE_STEP_ID="01878296-ff26-4b00-bd4d-c59d4ffb0614"
# export BUILDKITE_PROJECT_SLUG="o-1-labs-2/mina-o-1-labs"
# export BUILDKITE_PROJECT_PROVIDER="github"
# export BUILDKITE_AGENT_ID="01878cae-5bc3-4624-a25b-7999e7cf73b0"
# export BUILDKITE_AGENT_NAME="gke-central1-buildkite-agent-599948bcd5-d62gp-1"
# export BUILDKITE_AGENT_META_DATA_QUEUE="default"
# export BUILDKITE_AGENT_META_DATA_SIZE="generic"
# export BUILDKITE_STEP_IDENTIFIER="_MinaArtifactBullseye-build-deb-pkg"
