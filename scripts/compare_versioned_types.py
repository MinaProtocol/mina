#!/usr/bin/env python3

# compare representations of versioned types in OCaml files

# expects two Ocaml files possibly containing versioned types
#
# the first file is the original, the second is the modified file

import sys

from compare_versioned_items import run_comparison

# This is the list of file while has never been changed before
# and they haven't run through the CI before, and then fail 
# when modified.
skip_list = ["src/nonconsensus/snark_params/tick.ml"]

def skip(original, modified):
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
        run_comparison('_build/default/src/lib/ppx_version/tools/print_versioned_types.exe','Versioned types',sys.argv[1],sys.argv[2])
