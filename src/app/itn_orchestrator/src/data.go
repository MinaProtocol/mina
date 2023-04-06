package itn_orchestrator

import (
	"context"
	"encoding/json"

	"cloud.google.com/go/storage"
	logging "github.com/ipfs/go-log/v2"
)

type MetaToBeSaved struct {
	CreatedAt          string `json:"created_at"`
	PeerId             string `json:"peer_id"`
	SnarkWork          string `json:"snark_work,omitempty"`
	GraphqlControlPort uint16 `json:"graphql_control_port,omitempty"`
	RemoteAddr         string `json:"remote_addr"`
	Submitter          string `json:"submitter"`  // is base58check-encoded submitter's public key
	BlockHash          string `json:"block_hash"` // is base58check-encoded hash of a block
}

type RawParams map[string]json.RawMessage

type Command struct {
	Action string
	Params RawParams
}

type Scenario = []Command

type Config struct {
	Ctx          context.Context
	UptimeBucket *storage.BucketHandle
	GetGqlClient GetGqlClientF
	Log          logging.StandardLogger
}

type OutputF = func(name string, value any, multiple bool, sensitive bool)

type Action interface {
	Run(config Config, params json.RawMessage, output OutputF) error
}
