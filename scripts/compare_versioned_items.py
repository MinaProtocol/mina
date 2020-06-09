#!/usr/bin/env python3

# compare representations of versioned items in OCaml files

# expects two Ocaml files possibly containing versioned items (types, binable functors)
#
# the first file is the original, the second is the modified file

# for each file, we create a dictionary mapping module-paths to the items
# since we want to detect changes, we run this algorithm
#   for each item in the first file
#     if item from the second file is different, there's an error
#     if there is no item in the second file, that's OK (we can't serialize that type)
# new items in the second file are OK, we didn't change an existing serialization

import os
import sys
import subprocess
import tempfile

exit_code = 0

def create_dict (items_file) :
    with open (items_file, 'r') as fp :
        items = {}
        line = fp.readline()
        while line:
            line = line.strip (' \n')
            fields = line.split(':',1)
            items[fields[0]] = fields[1]
            line = fp.readline()
        return items

# expects files containing lines of the form
#  path:item
def compare_items (item_kind,fn,original,modified) :
    items_orig = create_dict (original)
    items_mod = create_dict (modified)
    for path in items_orig :
        orig = items_orig[path]
        try :
            mod = items_mod[path]
        except :
            mod = None
        if not (mod is None or mod == orig) :
            print ('In file: ' + fn)
            print ('  ' + item_kind + ' changed at module path: ' + path)
            print ('  Was: ' + orig)
            print ('  Now: ' + mod)
            global exit_code
            exit_code = 1

def create_items_file (printer,ocaml,tag) :
    out_fn = os.path.basename (ocaml) + '-' + tag
    if os.path.exists(out_fn) :
        os.remove(out_fn)
    with open (out_fn, 'w') as fp :
        retval = subprocess.run([printer,ocaml,'-o','/dev/null'],stdout=fp);
        # script should fail if printer fails
        retval.check_returncode ()
    return out_fn

def run_comparison (printer,item_kind,original,modified) :
    orig_items = create_items_file (printer,original,'original')
    mod_items = create_items_file (printer,modified,'modified')
    compare_items (item_kind,modified,orig_items,mod_items)
    sys.exit (exit_code)
