package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/libp2p/go-libp2p"
	peer "github.com/libp2p/go-libp2p-core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

func main() {
	// create a background context (i.e. one that never cancels)
	ctx := context.Background()

	// start a libp2p node that listens on a random local TCP port,
	// but without running the built-in ping protocol
	host, err := libp2p.New(ctx,
		libp2p.ListenAddrStrings("/ip4/0.0.0.0/tcp/0"),
		libp2p.Ping(false),
	)
	if err != nil {
		panic(err)
	}

	addrs := os.Args[1:]

	infos := make([]*peer.AddrInfo, len(addrs))
	for i, addr := range addrs {
		maddr, err := ma.NewMultiaddr(addr)
		if err != nil {
			panic(err)
		}

		infos[i], err = peer.AddrInfoFromP2pAddr(maddr)
		if err != nil {
			panic(err)
		}
	}

	online := make(map[string]bool)

	for _, info := range infos {
		err := host.Connect(ctx, *info)
		if err == nil {
			online[info.ID.String()] = true
		} else {
			online[info.ID.String()] = false
		}
	}

	prettyJSON, err := json.MarshalIndent(online, "", "    ")
	if err != nil {
		panic(err)
	}
	fmt.Println(string(prettyJSON))
}
