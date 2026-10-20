// Poll Mina Rosetta for new blocks and print transaction hashes.
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/MinaProtocol/mina/src/app/rosetta/examples/go/internal/config"
	"github.com/coinbase/rosetta-sdk-go/fetcher"
	"github.com/coinbase/rosetta-sdk-go/types"
)

const pollInterval = 10 * time.Second

func main() {
	env := config.Load()
	f := fetcher.New(env.URL)
	ctx := context.Background()

	height := startHeight(ctx, f, env.Network)
	fmt.Printf("Scanning from block %d\n", height)

	for {
		block, ferr := f.Block(ctx, env.Network, &types.PartialBlockIdentifier{Index: &height})
		if ferr != nil {
			log.Fatalf("Block %d: %s", height, ferr.Err)
		}
		if block == nil {
			time.Sleep(pollInterval)
			continue
		}

		fmt.Printf("[%s] block %d (%s) — %d tx\n",
			time.UnixMilli(block.Timestamp).UTC().Format(time.RFC3339),
			block.BlockIdentifier.Index, block.BlockIdentifier.Hash,
			len(block.Transactions))
		for _, tx := range block.Transactions {
			fmt.Printf("  %s\n", tx.TransactionIdentifier.Hash)
		}
		height++
	}
}

func startHeight(ctx context.Context, f *fetcher.Fetcher, network *types.NetworkIdentifier) int64 {
	if v := os.Getenv("START_HEIGHT"); v != "" {
		if h, err := strconv.ParseInt(v, 10, 64); err == nil && h > 0 {
			return h
		}
	}
	status, ferr := f.NetworkStatus(ctx, network, nil)
	if ferr != nil {
		log.Fatalf("NetworkStatus: %s", ferr.Err)
	}
	return status.CurrentBlockIdentifier.Index
}
