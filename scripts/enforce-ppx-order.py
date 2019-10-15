#!/usr/bin/python

# In dune files, enforce order of ppx processing. The static check ppx must precede the register_version ppx, which
# must precede the version ppx. Otherwise, a ppx may look for items that have been expanded away.

import subprocess
import string
import sexpdata

dune_string = subprocess.check_output(['find','src/lib','-name','dune'])

dunes_raw = string.split (dune_string,'\n')

dunes = list(filter(lambda s : len(s) > 0,dunes_raw))

library = sexpdata.loads ('library')
preprocess = sexpdata.loads ('preprocess')
pps = sexpdata.loads ('pps')
no_preprocessing = sexpdata.loads ('no_preprocessing')

ppx_static_checks = sexpdata.loads ('ppx_static_checks')
ppx_register_version = sexpdata.loads ('ppx_register_version')
ppx_versioning = sexpdata.loads ('ppx_coda')

exit_code = 0

def get_ppx_ndx (dune,ppxs,ppx) :
    try :
        ppxs.index (ppx)
    except :
        print ("In dune file " + dune + ", the preprocessing clause does not contain " + (sexpdata.dumps (ppx)))
        global exit_code
        exit_code = 1

def bad_ppx_order (dune,ppx1,ppx2) :
    print ("In dune file " + dune + ", in the preprocessing clause, " + (sexpdata.dumps (ppx1)) + " does not precede " + (sexpdata.dumps (ppx2)))
    global exit_code
    exit_code = 1

for dune in dunes :
    with open (dune) as fp :
        # wrap in parens to get list of top-level clauses
        sexps = sexpdata.loads ('(' + fp.read () + ')')
        for sexp in sexps :
            if isinstance (sexp,list) and len (sexp) > 0 and sexpdata.car (sexp) == library :
                clauses = sexpdata.cdr (sexp)
                for clause in clauses :
                    if sexpdata.car (clause) == preprocess :
                        subclause = sexpdata.car (sexpdata.cdr (clause))
                        if subclause == no_preprocessing :
                            # if no preprocessing, don't have to worry about order of ppxs
                            continue
                        elif sexpdata.car (subclause) == pps :
                            # if there is preprocessing, static checks before version registration before versioning, and all three must occur
                            ppxs = sexpdata.cdr (subclause)
                            static_checks_ndx = get_ppx_ndx (dune,ppxs,ppx_static_checks)
                            register_version_ndx = get_ppx_ndx (dune,ppxs,ppx_register_version)
                            versioning_ndx = get_ppx_ndx (dune,ppxs,ppx_versioning)
                            if (static_checks_ndx == None or register_version_ndx == None or versioning_ndx == None) :
                                continue
                            if not (static_checks_ndx < register_version_ndx) :
                                bad_ppx_order (dune,ppx_static_checks,ppx_register_version)
                            if not (register_version_ndx < versioning_ndx) :
                                bad_ppx_order (dune,ppx_register_version,ppx_versioning)
                        else :
                            print ("In dune file " + dune + ", in the library preprocessing clause, expected pps or no-preprocessing subclause in preprocess clause, got: " + str(subclause))
                            global exit_code
                            exit_code = 1

exit (exit_code)
