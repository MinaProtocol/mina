// Smoke test: fetch a single account's balance from Mina Rosetta.
package main

import (
	"context"
	"fmt"
	"log"

	"github.com/MinaProtocol/mina/src/app/rosetta/examples/go/internal/config"
	"github.com/coinbase/rosetta-sdk-go/fetcher"
	"github.com/coinbase/rosetta-sdk-go/types"
)

func main() {
	address, err := config.Required("TEST_ADDRESS")
	if err != nil {
		log.Fatal(err)
	}

	env := config.Load()
	f := fetcher.New(env.URL)

	block, balances, _, ferr := f.AccountBalance(
		context.Background(),
		env.Network,
		&types.AccountIdentifier{
			Address:  address,
			Metadata: map[string]interface{}{"token_id": config.DefaultTokenID},
		},
		nil,
		nil,
	)
	if ferr != nil {
		log.Fatalf("AccountBalance: %s", ferr.Err)
	}

	fmt.Printf("Address: %s\n", address)
	fmt.Printf("As of block %d (%s)\n", block.Index, block.Hash)
	for _, b := range balances {
		fmt.Printf("  %s %s (%d decimals)\n", b.Value, b.Currency.Symbol, b.Currency.Decimals)
	}
}
