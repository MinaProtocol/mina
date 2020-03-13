#!/usr/bin/env python3

# compare representations of binable functors in OCaml files in a Github pull request

# in CI, this script is run from git root of the PR branch

from compare_pr_diff_items import run_comparison

if __name__ == "__main__":
    if len(sys.argv) != 2 :
        print("Usage: %s Github-PR-URL" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    run_comparison(sys.argv[1],'compare_binables.py'
