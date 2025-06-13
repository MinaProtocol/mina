""" Cli & Debug entrypoint """

import json
import argparse
import os
import sys
from gcloud_entrypoint import handle_incoming_commit_push_json,config,verify_signature

parser = argparse.ArgumentParser()
parser.add_argument('--operation', "-o",type=str, help='debug operation to perform',required=True)
parser.add_argument('--payload', "-p",type=str, help='test file from github webhook push event',required=False)
parser.add_argument('--secret', "-s", type=str, help='secret for calculating signature',required=False)
parser.add_argument('--incoming_signature', "-i",type=str,  help='payload signature',required=False)

args = parser.parse_args()

if "verify" in args.operation:
    if not os.path.isfile(args.payload):
        sys.exit('cannot find test file :',args.payload)

    with open(args.payload,encoding="utf-8") as file:
        data = json.load(file)
        json_payload = json.dumps(data)
        verify_signature(json_payload, args.secret, "sha=" + args.incoming_signature)

elif "handle_payload" in args.operation:
    with open(args.payload,encoding="utf-8") as file:
        data = json.load(file)
        json_payload = json.dumps(data)
        handle_incoming_commit_push_json(data,config=config)
else:
    print("operation no supported", file=sys.stderr)