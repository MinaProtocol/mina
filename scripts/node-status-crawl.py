#!/usr/bin/env python3

# script to gather and store all node status data from peers reachable from the local daemon

import subprocess
import sys
import os
import argparse
import json

default_port=8301
default_prog='mina'

parser = argparse.ArgumentParser(description='Get node status from all Mina nodes reachable from localhost daemon')
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

# map from peer IDs to node status
node_statuses = dict ()

# the peer ids we've already queried
seen_peer_ids = set ()

def add_node_statuses (output) :

    lines = output.decode ('utf-8').split ('\n')

    # set of peers to query on next round
    peers_to_query = {}

    # populate map from responses
    for line in lines :
        if line == '' :
            continue

        status = json.loads (line)

        try :
            node_statuses[status['node_peer_id']] = status

            for peer in status['peers'] :
                peer_id = peer['peer_id']
                peers_to_query[peer_id] = peer
                # don't consider this peer_id again
                # the query to this peer may not succeed, though
                seen_peer_ids.add (peer_id)

        except :

            print ('Error in node status response: ' + line)

    return peers_to_query.items()

# get node status from peers known to daemon
output = subprocess.check_output([prog, 'advanced', 'node-status', '-daemon-peers', '-daemon-port', daemon_port])

peers_to_query = add_node_statuses (output)

done = False

def peer_to_multiaddr(peer):
    return '/ip4/{}/tcp/{}/p2p/{}'.format(
        peer['host'],
        peer['libp2p_port'],
        peer['peer_id'] )

# calculate fixpoint: add node statuses from peer ids until we see no new peer ids
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

    output = subprocess.check_output([prog, 'advanced', 'node-status', '-peers', formatted_peers, '-daemon-port', daemon_port])
    peers_to_query = add_node_statuses (output)



print ('{ "peer_ids_queried": ' + str(len(seen_peer_ids)) + ',')
print ('  "node_statuses": [')

num_node_statuses=len(node_statuses)
count = 0

for status in node_statuses.values () :
    s = str(status).replace("'",'"')
    if count < num_node_statuses - 1:
        print ('  ' + s + ',')
    else :
        print ('  ' + s)
    count += 1

print ('  ]}')
