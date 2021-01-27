#!/usr/bin/env python

from __future__ import print_function
import os
import sys
import requests

def main(required_file, branch_name):
    with open(required_file, 'r') as rf:
        required_status = list(filter(bool, rf.read().split('\n')))
        if not (len(required_status) > 0):
            print("required status was empty, this is probably in error and I refuse to turn off all status checks", file=sys.stderr)
            sys.exit(1)
        url = str.format("https://api.github.com/repos/MinaProtocol/mina/branches/{}/protection/required_status_checks", branch_name)
        r = requests.patch(url,
            json={"strict": True, "contexts": required_status},
            auth=('o1-service-account', os.environ['GITHUB_API_TOKEN']),
        )
        r.raise_for_status()

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: %s path_to_file_containing_required_status_checks branch_name" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1], sys.argv[2])
