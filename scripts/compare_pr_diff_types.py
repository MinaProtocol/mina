#!/usr/bin/env python3

# compare representations of versioned types in OCaml files in a Github pull request

# in CI, this script is run from git root of the PR branch

import sys

from compare_pr_diff_items import run_comparison

if __name__ == "__main__":
    if len(sys.argv) != 2 :
        print("Usage: %s base-branch" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    run_comparison(sys.argv[1],'compare_versioned_types.py')
