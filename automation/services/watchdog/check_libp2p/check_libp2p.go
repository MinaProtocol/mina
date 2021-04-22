package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"golang.org/x/crypto/blake2b"

	"github.com/libp2p/go-libp2p"
	peer "github.com/libp2p/go-libp2p-core/peer"
	libp2pmplex "github.com/libp2p/go-libp2p-mplex"

	ma "github.com/multiformats/go-multiaddr"
)

func main() {
	// create a background context (i.e. one that never cancels)
	ctx := context.Background()

	if len(os.Args) < 2 {
		panic("expecting first argument to be networkID")
	}

	networkID := os.Args[1]
	rendezvousString := fmt.Sprintf("/coda/0.0.1/%s", networkID)
	pnetKey := blake2b.Sum256([]byte(rendezvousString))

	// start a libp2p node that listens on a random local TCP port,
	// but without running the built-in ping protocol
	host, err := libp2p.New(ctx,
		libp2p.ListenAddrStrings("/ip4/0.0.0.0/tcp/0"),
		libp2p.Ping(false),
		libp2p.PrivateNetwork(pnetKey[:]),
		libp2p.Muxer("/coda/mplex/1.0.0", libp2pmplex.DefaultTransport),
	)
	if err != nil {
		panic(err)
	}

	addrs := os.Args[2:]

	infos := make([]*peer.AddrInfo, len(addrs))
	for i, addr := range addrs {
		maddr, err := ma.NewMultiaddr(addr)
		if err != nil {
			fmt.Fprintln(os.Stderr,err)
			panic(err)
		}

		infos[i], err = peer.AddrInfoFromP2pAddr(maddr)
		if err != nil {
			fmt.Fprintln(os.Stderr,err)
			panic(err)
		}
	}

	online := make(map[string]bool)

	for _, info := range infos {
		ctx, cancel := context.WithTimeout(ctx, time.Second*10)
		err := host.Connect(ctx, *info)
		if err == nil {
			online[info.ID.String()] = true
		} else {
			fmt.Fprintln(os.Stderr, err)
			online[info.ID.String()] = false
		}
		cancel()
	}

	prettyJSON, err := json.MarshalIndent(online, "", "    ")
	if err != nil {
		fmt.Println(err)
		panic(err)
	}
	fmt.Println(string(prettyJSON))
}
