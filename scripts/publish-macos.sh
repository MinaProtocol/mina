#!/bin/bash
set -euo pipefail

# Needed to check variables
set +u

GITHASH=$(git rev-parse --short=8 HEAD)
GITBRANCH=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD |  sed 's!/!-!; s!_!-!' )

# Make Portable Binary
make macos-portable

# Download JFrog CLI
curl -fL https://getcli.jfrog.io | sh

# Configure JFrog CLI
./jfrog rt config --url $ARTIFACTORY_URL --user $ARTIFACTORY_USER --apikey $ARTIFACTORY_API_KEY --interactive=false

# Upload Artifact to Artifactory
./jfrog rt u _build/coda-daemon-macos.zip macos-coda/coda-daemon-$GITBRANCH-$GITHASH.zip --build-name=build-macos --build-number=$CIRCLE_BUILD_NUM
