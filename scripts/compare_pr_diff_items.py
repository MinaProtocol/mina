#!/usr/bin/env python3

# compare representations of versioned items in OCaml files in a Github pull request

import os
import sys
import shutil
import subprocess

exit_code = 0


def run_comparison(base_commit, compare_script):
    cwd = os.getcwd()
    # create a copy of the repo at base branch
    if os.path.exists('base'):
        shutil.rmtree('base')
    os.mkdir('base')
    os.chdir('base')
    # it would be faster to do a clone of the local repo, but there's "smudge error" (?)
    subprocess.run(['git', 'clone', 'https://github.com/CodaProtocol/coda.git'])
    os.chdir('coda')
    subprocess.run(['git', 'checkout', base_commit])
    os.chdir(cwd)
    # changed files in the PR
    diffs_raw = subprocess.check_output(
        ['git', 'diff', '--name-only', base_commit])
    diffs_decoded = diffs_raw.decode('UTF-8')
    diffs = diffs_decoded.split('\n')
    for diff in diffs:
        fn = os.path.basename(diff)
        if not fn.endswith('.ml'):
            continue
        orig = 'base/coda/' + diff
        # don't compare if file added or deleted
        if not (os.path.exists(orig) and os.path.exists(diff)):
            continue
        completed_process = subprocess.run(
            ['./scripts/' + compare_script, orig, diff])
        if not completed_process.returncode == 0:
            global exit_code
            exit_code = 1
    sys.exit(exit_code)
