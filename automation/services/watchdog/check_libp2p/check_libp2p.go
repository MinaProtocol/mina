package main

import (
	"context"
  "fmt"
	"os"
  "encoding/json"

	"github.com/libp2p/go-libp2p"
)

func main() {
	// create a background context (i.e. one that never cancels)
	ctx := context.Background()

	// start a libp2p node that listens on a random local TCP port,
	// but without running the built-in ping protocol
	_, err := libp2p.New(ctx,
		libp2p.ListenAddrStrings("/ip4/0.0.0.0/tcp/0"),
		libp2p.Ping(false),
	)
	if err != nil {
		panic(err)
	}

  addrs := os.Args[1:]

  online := make(map[string]bool)

  for i := range addrs {
    addr := addrs[i]
    online[addr] = false
  }

  prettyJSON, err := json.MarshalIndent(online, "", "    ")
  fmt.Printf("%s\n", string(prettyJSON))
}
