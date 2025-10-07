package main

import (
	"fmt"
	"os"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/internal/app"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/internal/config"
)

func main() {
	if err := app.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}
