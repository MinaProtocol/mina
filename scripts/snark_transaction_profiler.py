#!/usr/bin/env python3

# script run transaction snark profiler
import subprocess
import sys
import os
import argparse
import json
import re
from datetime import datetime
from benchmarks.api import BenchmarkDb,Measurement



exit_code=0
prog = 'mina'
suite = 'Snark Profiler'
env = 'CI'
build_id = os.environ['BUILDKITE_JOB_ID']
now = datetime.now()
dt_string = now.strftime("%d/%m/%Y %H:%M:%S")

def set_error():
  global exit_code
  exit_code=1
    

def parse_stats (output) :

    print(output)

    lines = output.split ('\n')

    measurements = []

    for line in lines :
        if line == '' :
            continue

        compile = 'Generated zkapp transactions with (?P<updates>\d+) updates and (?P<proof>\d+) proof updates in (?P<time>[0-9]*[.]?[0-9]+) secs'

        match = re.match(compile, line)

        if match :

            updates = int(match.group('updates'))
            proof = int(match.group('proof'))
            time = float(match.group('time'))
            name ="zkapp transactions generation"
            measurements.append(Measurement(
                suite = suite,
                test_id = f'{name} with updates: {updates} proofs: {proof}',
                value = time,
                env = env,
                build_id =  build_id,
                timestamp = dt_string,
            ))    
                  
        compile = '\| (?P<updates>\d+)\| (?P<pairs>\d+)\| (?P<singles>\d+)\| (?P<verifications>[0-9]*[.]?[0-9]+)\| (?P<proving>[0-9]*[.]?[0-9]+)\|.*'

        match = re.match(compile, line)

        if match :
            name = "zkapp processing"
            updates = int(match.group('updates'))
            pairs = int(match.group('pairs'))
            singles = int(match.group('singles'))
            verifications = float(match.group('verifications'))
            proving = float(match.group('proving'))

            measurements.append(Measurement(
                suite = suite,
                test_id = f'{name} proving with updates: {updates} pairs: {pairs}',
                value = verifications + 10.0,
                env = env,
                build_id =  build_id,
                timestamp = dt_string,
            ))  

            measurements.append(Measurement(
                suite = suite,
                test_id = f'{name} verifications with updates: {updates} pairs: {pairs}',
                value = proving,
                env = env,
                build_id =  build_id,
                timestamp = dt_string,
            ))
       
    return measurements

if __name__ == "__main__":
    if len(sys.argv) != 4 :
        print("Usage: %s k max-num-updates min-num-updates" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    k=sys.argv[1]
    max_num_updates=sys.argv[2]
    min_num_updates=sys.argv[3]

    args = " ".join([prog, 
        "transaction-snark-profiler",
        "--zkapps",
        "--k",
        k,
        "--max-num-updates",
        max_num_updates,
        "--min-num-updates", 
        min_num_updates])


    print(f'running snark transaction profiler: {args}')
    process_exit_code = 0
    #(process_exit_code,output) = subprocess.getstatusoutput(args)
    with open('/home/darek/snark_profiler.out', 'r') as file:
        output = file.read()
    
    measurements = parse_stats (output)

    db = BenchmarkDb()
    degradated = db.check_measurements(measurements)

    if any(degradated):
        print(f'Performance degradation detected:')
        for threshold,measurement in degradated:
            print(f'\t{measurement.name}": mean(with grace value)={threshold} value={measurement.value}')    
    
        if db.bypass_degradation_enabled():
            print("bypassing degradation. It seems that this performance degradation was accepted, \
                thus saving measurement to db...")
            db.upload_benchmark_data(measurements)
        else:
            exit_code = -1

    if not process_exit_code == 0:
        print('non-zero exit code from program, failing build')
        sys.exit(process_exit_code)
    else:
        sys.exit(exit_code)