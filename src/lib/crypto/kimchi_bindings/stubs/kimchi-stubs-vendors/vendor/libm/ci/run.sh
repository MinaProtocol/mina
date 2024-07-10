#!/usr/bin/env sh

set -ex
TARGET=$1

CMD="cargo test --all --target $TARGET"

# Needed for no-panic to correct detect a lack of panics
export RUSTFLAGS="$RUSTFLAGS -Ccodegen-units=1"

# stable by default
$CMD
$CMD --release

# unstable with a feature
$CMD --features 'unstable'
$CMD --release --features 'unstable'

# also run the reference tests
$CMD --features 'unstable musl-reference-tests'
$CMD --release --features 'unstable musl-reference-tests'
