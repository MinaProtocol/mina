"""A daemon, as far as Rosetta's network check is concerned.

Rosetta validates the network on every /account/balance by asking the daemon
`query { networkID }` and comparing the answer with the identifier in the
request. On this path that is the only thing it wants a daemon for, so this
answers exactly that and nothing else, which keeps the test about the archive.

Usage: gql-network-stub.py <port> [network-id]
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

NETWORK_ID = sys.argv[2] if len(sys.argv) > 2 else "mina:devnet"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("content-length", 0))
        self.rfile.read(length)
        body = json.dumps({"data": {"networkID": NETWORK_ID}}).encode()
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
