apt install -y aptly

DISTRIBUTION=$1
DEBS=$2
COMPONENT=unstable
REPO="$DISTRIBUTION-$COMPONENT"

rm -rf ~/.aptly

aptly repo create --compontent $COMPONENT --distribution $DISTRIBUTION  $REPO

aptly repo add $REPO $DEBS

aptly publish snapshot -distribution=$DISTRIBUTION -skip-signing $COMPONENT

export APTLY_LISTEN="aptly_${BUILDKITE_JOB_ID}:10000"
export APTLY_PID=$!

aptly serve -listen $APTLY_LISTEN &