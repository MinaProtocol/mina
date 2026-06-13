// Package config centralizes the Mina-specific Rosetta knobs and shared env
// parsing the example programs need.
package config

import (
	"fmt"
	"os"

	"github.com/coinbase/rosetta-sdk-go/types"
)

const (
	Blockchain      = "mina"
	CurveType       = types.Pallas
	DefaultTokenID  = "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf"
	DefaultURL      = "http://localhost:3087"
	DefaultNetwork  = "devnet"
)

var MinaCurrency = &types.Currency{Symbol: "MINA", Decimals: 9}

// Env returns the example-script configuration sourced from environment
// variables. Defaults match the TypeScript examples.
type Env struct {
	URL     string
	Network *types.NetworkIdentifier
}

func Load() *Env {
	url := os.Getenv("ROSETTA_URL")
	if url == "" {
		url = DefaultURL
	}
	network := os.Getenv("NETWORK")
	if network == "" {
		network = DefaultNetwork
	}
	return &Env{
		URL:     url,
		Network: &types.NetworkIdentifier{Blockchain: Blockchain, Network: network},
	}
}

// Required reads a required env var, returning a friendly error if unset.
func Required(name string) (string, error) {
	v := os.Getenv(name)
	if v == "" {
		return "", fmt.Errorf("missing env var: %s", name)
	}
	return v, nil
}
