#!/bin/bash

set -eou pipefail

eval $(opam config env) && ./scripts/compare_test_signatures.sh

