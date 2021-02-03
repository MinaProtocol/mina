#!/usr/bin/python3

from collections import Counter
import subprocess
import json
import time
import sys
import graphyte
import math


def cli(cmd='uname'):
    result = subprocess.run(cmd.split(), stdout=subprocess.PIPE)
    return(result.stdout.decode('utf-8').strip())

# Load sensitive config
try:
    with open('/etc/testnet_config.json') as config_file:
        config = json.load(config_file)
        testnet = config['testnet']

except IOError as error:
    print('Error opening secrets config:', error)
    sys.exit(1)

status = cli('mina client status -json')
block = json.loads(status)['blockchain_length']
print('Block:', block)

snark_job_list = json.loads(cli('mina advanced snark-job-list'))

leavestotal= Counter()

treecount = 0
for tree in snark_job_list:
    print('=' * 70)
    print('🌲:', treecount, 'Size:', len(tree))
    treecount += 1
    leavesbytree = Counter()

    output_line = ''
    for job in tree:
        (slotid, data) = job

        # merge proofs
        if 'M' in data:
            if len(data['M']) > 0:
                output_line += str(len(data['M']))
            else:
                output_line += '_'
        # transactions proofs (leaves)
        elif 'B' in data:
            if len(data['B']) > 0:
                leavesbytree['occupied'] += 1
                leavestotal['occupied'] += 1

                if 'Status' in data['B'][2]:
                    if data['B'][2]['Status'] == 'Todo':
                        output_line += 'b'
                    elif data['B'][2]['Status'] == 'Done':
                        output_line += 'B'
                    else:
                        output_line += '?'

            else:
                leavesbytree['empty'] += 1
                leavestotal['empty'] += 1
                output_line += '_'
            leavesbytree['total'] += 1
            leavestotal['total'] += 1
        else:
            # should never get here
            print('fouind no match:', data)

        # Print lines on powers of 2
        if (not math.log(slotid + 2, 2) % 1):
            # print a new line for a new level of tree
            print(output_line.center(int(len(tree)/2)))
            output_line = ''



    print(leavesbytree)
print('TOTALS:', leavestotal)