""" Cli & Debug entrypoint """

import argparse
import json
import os
import sys
from github_autosync.gcloud_entrypoint.lib.config import *
from github_autosync.gcloud_entrypoint.git_merge_me import handle_incoming_comment,handle_incoming_push
from github_autosync.gcloud_entrypoint.stable_branch import handle_incoming_commit_push_in_stable_branches
from github_autosync.gcloud_entrypoint.lib import GithubPayloadInfo, config

main = argparse.ArgumentParser()

subparsers = main.add_subparsers(dest="subparser")

verify = subparsers.add_parser('verify')
verify.add_argument('--payload', "-p", type=str, help='test file from github webhook push event', required=False)
verify.add_argument('--secret', "-s", type=str, help='secret for calculating signature', required=False)
verify.add_argument('--incoming_signature', "-i", type=str, help='payload signature', required=False)

help_merge_me = subparsers.add_parser('help-merge-me')

help_merge_me_subparsers = help_merge_me.add_subparsers(dest="help_merge_me")

help_merge_me_comment = help_merge_me_subparsers.add_parser('comment')
help_merge_me_comment.add_argument('--payload', "-p", type=str, help='test file from github webhook comment event', required=True)
help_merge_me_comment.add_argument('--config', "-c", type=str, help='configuration file', required=True)

help_merge_me_push = help_merge_me_subparsers.add_parser('push')
help_merge_me_push.add_argument('--incoming-branch', "-i", type=str, help='branch which received change', required=True)
help_merge_me_push.add_argument('--config', "-c", type=str, help='configuration file', required=True)


verify = subparsers.add_parser('sync')
verify.add_argument('--incoming-branch', "-i", type=str, help='branch which received change', required=True)
verify.add_argument('--config', "-c", type=str, help='configuration file', required=True)

args = main.parse_args()

if args.subparser == "verify":
    if not os.path.isfile(args.payload):
        sys.exit(f'cannot find test file {args.payload}')

    with open(args.payload, encoding="utf-8") as file:
        data = json.load(file)
        json_payload = json.dumps(data)
        #verify_signature(json_payload, args.secret, "sha=" + args.incoming_signature)

elif args.subparser == "help-merge-me":
    if args.help_merge_me == "comment":
        with open(args.payload, encoding="utf-8") as payload:
            data = json.load(payload)
            json_info = GithubPayloadInfo(data)
            handle_incoming_comment(json_info,configuration=config.load(args.config))
    elif args.help_merge_me == "push":
        handle_incoming_push(args.incoming_branch, configuration=config.load(args.config))
    else:
        print("operation no supported", file=sys.stderr)

elif args.subparser == "sync":
    handle_incoming_commit_push_in_stable_branches(args.incoming_branch,configuration=config.load(args.config))
else:
    print("operation no supported", file=sys.stderr)
