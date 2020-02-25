#!/usr/bin/env python3

# script to find common best-tip prefix over a list of nodes using GraphQL query

import os
import sys
import json
import CodaClient

def main (ip_addrs) :
    common_prefix = None
    for ip_addr in ip_addrs :
        client = CodaClient.Client (graphql_host=ip_addr)
        result = client._send_query (query="query bestChainQuery { bestChain { stateHash } }")
        chain = result['data']['bestChain']
        if common_prefix is None :
            common_prefix = chain
        else :
            common_prefix = os.path.commonprefix ([chain,common_prefix])
    print (common_prefix)
        
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: %s ip_addr0 ..." % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1:])
