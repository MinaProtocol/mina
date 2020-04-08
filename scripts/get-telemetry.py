#!/usr/bin/env python3

# script to gather and store all telemetry from peers reachable from the local daemon

import subprocess
import sys
import os
import json

# map from peer IDs to telemetry data
telemetries = dict ()

# the peer ids we've already queried
seen_peer_ids = set ()

def add_telemetries (output) :

    lines = output.decode ('utf-8').split ('\n')

    # set of peers to query on next round
    peer_ids_to_query = set ()

    # populate map from responses
    for line in lines :
        if line == '' :
            continue

        telem = json.loads (line)

        try :

            telemetries[telem['node_peer_id']] = telem

            for peer in telem['peers'] :
                peer_id = peer['peer_id']
                peer_ids_to_query.add (peer_id)
                # don't consider this peer_id again
                # the query to this peer may not succeed, though
                seen_peer_ids.add (peer_id)

        except :

            print ('Error in telemetry response: ' + line)

    return peer_ids_to_query

# get telemetry data from peers known to daemon
output = subprocess.check_output(['coda', 'advanced', 'telemetry', '-daemon-peers'])

peer_ids_to_query = add_telemetries (output)

done = False

# calculate fixpoint: add telemetries from peer ids until we see no new peer ids
while not done :

    done = True

    formatted_peer_ids = ''

    for peer_id in peer_ids_to_query :

        if peer_id in seen_peer_ids :
            continue
        else :
            done = False
            if peer_id_count == 0 :
                formatted_peer_ids = peer_id
            else :
                formatted_peer_ids = peer_id + ',' + formatted_peer_ids

    if done :
        break

    output = subprocess.check_output(['coda', 'advanced', 'telemetry', '-peer-ids', formatted_peer_ids])
    peer_ids_to_query = add_telemetries (output)

print ('Peer IDs queried: ' + str(len(seen_peer_ids)))

# TODO : store the telemetries in a DB, like MongoDB
