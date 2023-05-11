#!/bin/bash

set -eou pipefail

eval $(opam config env) && export PATH=$HOME/.cargo/bin:$PATH && ./scripts/zkapp_metrics.sh
