#!/usr/bin/python

# In dune files, whenever there's preprocessing, the static enforcement ppx appears before the versioning ppx, because the
# former checks for occurrences of the latter, so we don't want it expanded away

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
ppx_versioning = sexpdata.loads ('ppx_coda')

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
                            # if there is preprocessing, static checks before versioning, and both must occur
                            ppxs = sexpdata.cdr (subclause)
                            try :
                                static_checks_ndx = ppxs.index (ppx_static_checks)
                            except :
                                print ("In dune file " + dune + ", did not find ppx " + (sexpdata.dumps (ppx_static_checks)))
                                exit (1)
                            try :
                                versioning_ndx = ppxs.index (ppx_versioning)
                            except :
                                print ("In dune file " + dune + ", did not find ppx " + (sexpdata.dumps (ppx_versioning)))
                                exit (1)
                            if not (static_checks_ndx < versioning_ndx) :
                                print ("In dune file " + dune + ", in preprocessing clause, " + (sexpdata.dumps (ppx_static_checks)) + " does not precede " + (sexpdata.dumps (ppx_versioning)))
                                exit (1)
                        else :
                            print ("In dune file " + dune + ", in library preprocessing clause, expected pps or no-preprocessing subclause in preprocess clause, got: " + str(subclause))
                            exit (1)

                          

                              
                
            
            

      
      

    

