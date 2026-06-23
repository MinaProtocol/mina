// mina-bootstrap is a CLI that automates the pre-staging steps required to
// run a Mina archive node, daemon, or Rosetta stack: fetching archive dumps,
// precomputed blocks, replayer checkpoints, and similar artifacts published
// by the Mina Foundation.
//
// See README.md for usage and design notes.
package main

import (
	"os"

	"github.com/MinaProtocol/mina/src/app/bootstrap/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		os.Exit(1)
	}
}
