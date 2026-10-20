// Watch a Mina address for incoming MINA deposits.
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

const (
	pollInterval = 10 * time.Second
	depositOp    = "payment_receiver_inc"
)

func main() {
	address, err := config.Required("TEST_ADDRESS")
	if err != nil {
		log.Fatal(err)
	}

	env := config.Load()
	f := fetcher.New(env.URL)
	ctx := context.Background()

	height := startHeight(ctx, f, env.Network)
	fmt.Printf("Watching %s for deposits starting at block %d\n", address, height)

	for {
		block, ferr := f.Block(ctx, env.Network, &types.PartialBlockIdentifier{Index: &height})
		if ferr != nil {
			log.Fatalf("Block %d: %s", height, ferr.Err)
		}
		if block == nil {
			time.Sleep(pollInterval)
			continue
		}

		for _, deposit := range findDeposits(block, address) {
			fmt.Printf("DEPOSIT  block=%d  tx=%s  amount=%s nanomina\n",
				deposit.height, deposit.txHash, deposit.amount)
		}
		height++
	}
}

type deposit struct {
	height int64
	txHash string
	amount string
}

func findDeposits(block *types.Block, address string) []deposit {
	var out []deposit
	for _, tx := range block.Transactions {
		for _, op := range tx.Operations {
			if !isDeposit(op, address) {
				continue
			}
			out = append(out, deposit{
				height: block.BlockIdentifier.Index,
				txHash: tx.TransactionIdentifier.Hash,
				amount: op.Amount.Value,
			})
		}
	}
	return out
}

func isDeposit(op *types.Operation, address string) bool {
	if op.Type != depositOp {
		return false
	}
	if op.Status != nil && *op.Status == "Failed" {
		return false
	}
	if op.Account == nil || op.Account.Address != address {
		return false
	}
	return op.Amount != nil
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
