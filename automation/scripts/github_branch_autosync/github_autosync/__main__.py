""" Cli & Debug entrypoint """

import json
import argparse
import os
import sys
from gcloud_entrypoint import handle_incoming_commit_push_json,config

parser = argparse.ArgumentParser()
parser.add_argument('test_json', help='test file from github webhook push event')

args = parser.parse_args()

if not os.path.isfile(args.test_json):
    sys.exit('cannot find test file :',args.test_json)

with open(args.test_json,encoding="utf-8") as file:
    data = json.load(file)
    handle_incoming_commit_push_json(data,config=config)
