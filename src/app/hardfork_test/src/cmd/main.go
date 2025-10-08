package main

import (
	"fmt"
	"os"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/app"
)

func main() {
	if err := app.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}
