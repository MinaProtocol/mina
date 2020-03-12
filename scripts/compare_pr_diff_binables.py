#!/usr/bin/env python3

# compare representations of binable functors in OCaml files in a Github pull request

# in CI, this script is run from git root of the PR branch

import os
import sys
import shutil
import subprocess
import json

exit_code = 0

# pr_url is of form https://github.com/CodaProtocol/coda/pull/n
def main (pr_url) :
  pr_number = os.path.basename (pr_url)
  api_url = 'https://api.github.com/repos/CodaProtocol/coda/pulls/' + pr_number
  pr_json = 'pr.json'
  if os.path.exists(pr_json) :
     os.remove(pr_json)
  subprocess.run(['curl',api_url,'-H','Accept: application/vnd.github.v3.json','-o',pr_json])
  with open (pr_json, 'r') as fp :
    json_obj = json.load (fp)
  base = json_obj['base']['ref']
  cwd = os.getcwd ()
  # create a copy of the repo at base branch
  if os.path.exists ('base') :
    shutil.rmtree ('base')
  os.mkdir ('base')
  os.chdir ('base')
  # it would be faster to do a clone of the local repo, but there's "smudge error" (?)
  subprocess.run(['git','clone','git@github.com:CodaProtocol/coda.git'])
  os.chdir (cwd)
  # changed files in the PR
  diffs_raw = subprocess.check_output(['git','diff','--name-only','origin/' + base])
  diffs_decoded = diffs_raw.decode ('UTF-8')
  diffs = diffs_decoded.split ('\n')
  for diff in diffs :
     fn = os.path.basename (diff)
     if not fn.endswith ('.ml') :
       continue
     orig = 'base/coda/' + diff
     # don't compare if file added or deleted
     if not (os.path.exists (orig) and os.path.exists (diff)) :
       continue
     completed_process = subprocess.run(['./scripts/compare_binables.py',orig,diff])
     if not completed_process.returncode == 0 :
       global exit_code
       exit_code = 1
  sys.exit (exit_code)

if __name__ == "__main__":
    if len(sys.argv) != 2 :
        print("Usage: %s Github-PR-URL" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1])
