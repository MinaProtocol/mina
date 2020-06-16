#!/usr/bin/env python3

# compare representations of versioned types in OCaml files

# expects two Ocaml files possibly containing versioned types
#
# the first file is the original, the second is the modified file

import sys

from compare_versioned_items import run_comparison

if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] == sys.argv[2] :
        print("Usage: %s path1-to-file.ml path2-to-file.ml" % sys.argv[0], file=sys.stderr)
        print("The .ml files must have the same name, with different paths")
        sys.exit(1)

    run_comparison('_build/default/src/external/ppx_version/src/print_versioned_types.exe','Versioned types',sys.argv[1],sys.argv[2])
