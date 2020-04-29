#!/usr/bin/env python3

# generate an .ml file containing the genesis identifier for use by genesis_ledger_helper, so it knows
#  the name of the proof file, which uses that identifier as a suffix

# example proof filename: "genesis_proof.coda_genesis_ea87d673_bc1dceef64d3d847"

# the consensus code hashes constants to generate that id; the nonconsensus code doesn't
#  have those constants available

import os
import sys

genesis_filename = './_build/default/src/app/runtime_genesis_ledger/genesis_filename.txt'

genesis_id_ml = './src/nonconsensus/genesis_ledger_helper/genesis_id.ml'

def generate_genesis_dir_ml_file () :
    got_file = os.path.isfile(genesis_filename)

    if not got_file :
        print ('Could not find genesis filename at ' + genesis_filename,file=sys.stderr)
        print ('Please run \'make genesis_ledger\' and run this script again',file=sys.stderr)
        exit (1)

    with open(genesis_filename,'r') as file :
        genesis_id = file.read()

    with open(genesis_dir_ml,'w') as file:
        file.write ('(* GENERATED FILE -- DO NOT EDIT *)\n')
        file.write ('\n')
        file.write ('let genesis_id = \"' + genesis_id + '\"\n')

if __name__ == "__main__":
    generate_genesis_dir_ml_file ()
