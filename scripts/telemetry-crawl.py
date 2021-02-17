#!/usr/bin/env python3

# script to gather and store all telemetry from peers reachable from the local daemon

import subprocess
import sys
import os
import argparse
import json

default_port=8301
default_prog='coda'

parser = argparse.ArgumentParser(description='Get telemetry data from all Mina nodes reachable from localhost daemon')
parser.add_argument('--daemon-port',
                    help='daemon port on localhost (default: ' + str(default_port) + ')')
parser.add_argument('--executable',
                    help='Mina program on localhost (default: ' + str(default_prog) + ')')

args = parser.parse_args()

if args.daemon_port is None :
    daemon_port = str(default_port)
else :
    daemon_port = args.daemon_port

if args.executable is None :
    prog = default_prog
else :
    prog = args.executable

# map from peer IDs to telemetry data
telemetries = dict ()

# the peer ids we've already queried
seen_peer_ids = set ()

def add_telemetries (output) :

    lines = output.decode ('utf-8').split ('\n')

    # set of peers to query on next round
    peers_to_query = {}

    # populate map from responses
    for line in lines :
        if line == '' :
            continue

        telem = json.loads (line)

        try :
            telemetries[telem['node_peer_id']] = telem

            for peer in telem['peers'] :
                peer_id = peer['peer_id']
                peers_to_query[peer_id] = peer
                # don't consider this peer_id again
                # the query to this peer may not succeed, though
                seen_peer_ids.add (peer_id)

        except :

            print ('Error in telemetry response: ' + line)

    return peers_to_query.items()

# get telemetry data from peers known to daemon
output = subprocess.check_output([prog, 'advanced', 'telemetry', '-daemon-peers', '-daemon-port', daemon_port])

peers_to_query = add_telemetries (output)

done = False

def peer_to_multiaddr(peer):
    return '/ip4/{}/tcp/{}/p2p/{}'.format(
        peer['host'],
        peer['libp2p_port'],
        peer['peer_id'] )

# calculate fixpoint: add telemetries from peer ids until we see no new peer ids
while not done :

    done = True

    formatted_peers = ''

    for (peer_id, peer) in peers_to_query :
        peer = peer_to_multiaddr(peer)

        if peer_id in seen_peer_ids :
            continue
        else :
            done = False
            if peer_id_count == 0 :
                formatted_peers = peer
            else :
                formatted_peers = peer + ',' + formatted_peers

    if done :
        break

    output = subprocess.check_output([prog, 'advanced', 'telemetry', '-peers', formatted_peers, '-daemon-port', daemon_port])
    peers_to_query = add_telemetries (output)



print ('{ "peer_ids_queried": ' + str(len(seen_peer_ids)) + ',')
print ('  "telemetries": [')

num_telemetries=len(telemetries)
count = 0

for telem in telemetries.values () :
    s = str(telem).replace("'",'"')
    if count < num_telemetries - 1:
        print ('  ' + s + ',')
    else :
        print ('  ' + s)
    count += 1

print ('  ]}')
