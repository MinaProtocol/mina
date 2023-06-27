#!/usr/bin/env python3

# script run transaction snark profiler and upload data to bucket

import subprocess
import sys
import os
import argparse
import json
import re

exit_code=0
prog = '_build/default/src/app/cli/src/mina.exe'

def set_error():
  global exit_code
  exit_code=1

def parse_stats (output) :

    print(output)

    lines = output.decode ('utf-8').split ('\n')

    stats = []

    for line in lines :
        if line == '' :
            continue
        try :
            compile = '/Generated zkapp transactions with (?<updates>\d+) updates and (?<proof>\d+) proof updates in (?<time>[0-9]*[.]?[0-9]+) secs/gms'

            match = re.search(compile, line)
            updates = int(match.group('updates'))
            proof = int(match.group('proof'))
            time = float(match.group('time'))

            stats.append((updates, proof, time))
        except :
            print ('Error in line: ' + line)
            set_error           

    return stats

if __name__ == "__main__":
    if len(sys.argv) != 4 :
        print("Usage: %s k max-num-updates min-num-updates" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    k=sys.argv[1]
    max_num_updates=sys.argv[2]
    min_num_updates=sys.argv[3]

    args =  [prog, 
        "transaction-snark-profiler",
        "--zkapps",
        "--k",
        k,
        "--max-num-updates",
        max_num_updates,
        "--min-num-updates", 
        min_num_updates]


    print(f'running snark transaction profiler: \'{" ".join(args)}\'')
    (process_exit_code,output) = subprocess.getstatusoutput(args)
    stats = parse_stats (output)
    print(stats)
    

    if not process_exit_code == 0:
        print('non-zero exit code from program, failing build')
        sys.exit(process_exit_code)
    else:
        sys.exit(exit_code)