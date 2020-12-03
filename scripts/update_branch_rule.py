#!/usr/bin/env python

from __future__ import print_function
import os
import sys
import requests

def main(required_file):
    with open(required_file, 'r') as rf:
        required_status = list(filter(bool, rf.read().split('\n')))
        if not (len(required_status) > 0):
            print("required status was empty, this is probably in error and I refuse to turn off all status checks", file=sys.stderr)
            sys.exit(1)
        r = requests.patch("https://api.github.com/repos/MinaProtocol/mina/branches/develop/protection/required_status_checks",
            json={"strict": True, "contexts": required_status},
            auth=('o1-service-account', os.environ['GITHUB_API_TOKEN']),
        )
        r.raise_for_status()

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: %s path_to_file_containing_required_status_checks" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1])
