""" Cli & Debug entrypoint """

import json
import argparse
import os
import sys
from gcloud_entrypoint import handle_incoming_commit_push_json,config,verify_signature

parser = argparse.ArgumentParser()
parser.add_argument('payload', help='test file from github webhook push event')
parser.add_argument('secret', help='secret for calculating signature')
parser.add_argument('incoming_signature', help='payload signature')

args = parser.parse_args()

if not os.path.isfile(args.payload):
    sys.exit('cannot find test file :',args.payload)

with open(args.payload,encoding="utf-8") as file:
    data = json.load(file)
    json_payload = json.dumps(data)
    verify_signature(json_payload, args.secret, "sha=" + args.incoming_signature)