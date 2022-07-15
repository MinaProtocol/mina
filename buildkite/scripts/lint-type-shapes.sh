#!/bin/bash

set -eou pipefail

source buildkite/scripts/export-git-env-vars.sh

eval $(opam config env) && export PATH=$HOME/.cargo/bin:$PATH && ./scripts/compare_ci_type_shapes.sh
