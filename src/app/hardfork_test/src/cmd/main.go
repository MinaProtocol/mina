package main

import (
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/app"
)

func main() {
	// TODO: remove this random seeding when we're using go 1.20 or newer, this is
	// needed for now because old go version doesn't seed randomness by default
	rand.Seed(time.Now().UnixNano())
	if err := app.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	} else {
		fmt.Printf("HF test completed successfully")
	}
}
