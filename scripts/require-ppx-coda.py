#!/usr/bin/python

# In dune files, require preprocessing by ppx_coda, so that the version syntax linter is always run

import subprocess
import string
import sexpdata

dune_string = subprocess.check_output(['find','src','-name','dune'])

dunes_raw = string.split (dune_string,'\n')

# filter out dunes where we don't require linting
def dunes_ok (dune) :
  path = dune.split ('/')
  path_prefix2 = path[1:2]
  path_prefix3 = path[1:3]
  return (not (path_prefix2 == ['_build'] or path_prefix2 == ['external'] or
               path_prefix3 == ['lib', 'snarky'] or path_prefix3 == ['lib', 'ppx_coda']))

dunes = list(filter(lambda s : len(s) > 0 and dunes_ok (s),dunes_raw))

library = sexpdata.loads ('library')
preprocess = sexpdata.loads ('preprocess')
pps = sexpdata.loads ('pps')
no_preprocessing = sexpdata.loads ('no_preprocessing')

ppx_lint = sexpdata.loads ('ppx_coda')

exit_code = 0

def ppx_error (dune,ppx) :
    print ("In dune file " + dune + ", the preprocessing clause does not contain " + (sexpdata.dumps (ppx)) + ", or is missing")
    global exit_code
    exit_code = 1

def get_ppx_ndx (dune,ppxs,ppx) :
    try :
        ppxs.index (ppx)
    except :
        ppx_error (dune,ppx)

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
                            # error if no preprocessing explicitly
                            ppx_error (dune,ppx_lint)
                        elif sexpdata.car (subclause) == pps :
                            ppxs = sexpdata.cdr (subclause)
                            lint_ppx_ndx = get_ppx_ndx (dune,ppxs,ppx_lint)
                        else :
                            # error if no preprocessing implicitly
                            ppx_error (dune,ppx_lint)

exit (exit_code)
