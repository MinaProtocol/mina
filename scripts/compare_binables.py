#!/usr/bin/env python3

# compare representations of binable functors in OCaml files

# expects two Ocaml files possibly containing included binable functors
#
# the first file is the original, the second is the modified file

# for each file, we create a dictionary mapping module-paths to the functor definitions
# since we want to detect changes, we run this algorithm
#   for each functor in the first file
#     if the functor from the second file is different, there's an error
#     if there is no functor the second file, that's OK (we can't serialize a type based on that functor)
# new functor uses in the second file are OK, we didn't change an existing serialization

import os
import sys
import subprocess
import tempfile

exit_code = 0

run_ppx_coda='_build/default/src/lib/ppx_coda/run_ppx_coda.exe'

def create_dict (binables_file) :
    with open (binables_file, 'r') as fp :
        binables = {}
        line = fp.readline()
        while line:
            line = line.strip (' \n')
            fields = line.split(':',1)
            binables[fields[0]] = fields[1]
            line = fp.readline()
        return binables

# expects files containing lines of the form
#  path:type_definition
def compare_binables (fn,original,modified) :
    binables_orig = create_dict (original)
    binables_mod = create_dict (modified)
    for path in binables_orig :
        orig = binables_orig[path]
        try :
            mod = binables_mod[path]
        except :
            mod = None
        if not (mod is None or mod == orig) :
            print ('In file: ' + fn)
            print ('  Binable functor changed at module path: ' + path)
            print ('  Was: ' + orig)
            print ('  Now: ' + mod)
            global exit_code
            exit_code = 1

def create_binables_file (ocaml,tag) :
    out_fn = os.path.basename (ocaml) + '-' + tag
    if os.path.exists(out_fn) :
        os.remove(out_fn)
    with open (out_fn, 'w') as fp :
        subprocess.run([run_ppx_coda,ocaml,'-o','/dev/null'],stdout=fp)
    return out_fn

def main (original,modified) :
    orig_binables = create_binables_file (original,'original')
    mod_binables = create_binables_file (modified,'modified')
    compare_binables (modified,orig_binables,mod_binables)
    sys.exit (exit_code)

if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] == sys.argv[2] :
        print("Usage: %s path1-to-file.ml path2-to-file.ml" % sys.argv[0], file=sys.stderr)
        print("The .ml files must have the same name, with different paths")
        sys.exit(1)

    main(sys.argv[1],sys.argv[2])
