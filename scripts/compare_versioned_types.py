#!/usr/bin/env python3

# compare representations of versioned types in OCaml files

# expects two Ocaml files possibly containing versioned types
#
# the first file is the original, the second is the modified file

import sys

from compare_versioned_items import run_comparison

error_msg = "Please see this issue https://github.com/MinaProtocol/mina/issues/11780 for pointers on how to fix this error. It might be also helpful to look in this file: `scripts/compare_verioned_types.py"

# This is the list of file while has never been changed before
# and they haven't run through the CI before, and then fail 
# when modified. To add new files, just add them to this list.
skip_list = ["src/nonconsensus/snark_params/tick.ml"]

# This function determines if a particular file should be skipped
# version compatibility check in the CI check.
# `modified` is the name of the file we have modified in the branch of a PR.
# `original` is the name of the equivalent file in at the HEAD of the branch
# you want to merge into (this is usually develop or compatible)
# They basically have the same names, but different paths.
def skip(original, _modified):
    for skip_item in skip_list:
        if skip_item in original:
            return True
    return False

if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] == sys.argv[2] :
        print("Usage: %s path1-to-file.ml path2-to-file.ml" % sys.argv[0], file=sys.stderr)
        print("The .ml files must have the same name, with different paths")
        sys.exit(1)

    if not (skip (sys.argv[1], sys.argv[2])):  
        status_code = run_comparison('_build/default/src/lib/ppx_version/tools/print_versioned_types.exe','Versioned types',sys.argv[1],sys.argv[2])
        if status_code != 0:
            print(error_msg)
            sys.exit(status_code)
