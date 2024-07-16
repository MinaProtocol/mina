package itn_orchestrator

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"time"

	"github.com/Khan/genqlient/graphql"
	logging "github.com/ipfs/go-log/v2"
)

type MiniMetaToBeSaved struct {
	GraphqlControlPort uint16 `json:"graphql_control_port,omitempty"`
	RemoteAddr         string `json:"remote_addr"`
	Submitter          string `json:"submitter"` // is base58check-encoded submitter's public key
}

type MetaToBeSaved struct {
	MiniMetaToBeSaved
	CreatedAt string `json:"created_at"`
	PeerId    string `json:"peer_id"`
	SnarkWork string `json:"snark_work,omitempty"`
	BlockHash string `json:"block_hash"` // is base58check-encoded hash of a block
}

type RawParams map[string]json.RawMessage

type Command struct {
	Action string
	Params RawParams
}

type NodeAddress string

type NodeEntry struct {
	Client          graphql.Client
	Libp2pPort      uint16
	PeerId          string
	IsBlockProducer bool
	LastStatusCode  *int
}

type Config struct {
	Ctx                context.Context
	AwsContext         *AwsContext
	OnlineURL          string
	Sk                 ed25519.PrivateKey
	Log                logging.StandardLogger
	MinaExec           string
	NodeData           map[NodeAddress]NodeEntry
	SlotDurationMs     int
	GenesisTimestamp   time.Time
	ControlExec        string
	StopDaemonDelaySec int
	FundDaemonPorts    []string
}

type OutputF = func(name string, value any, multiple bool, sensitive bool)

type ActionIO struct {
	Params json.RawMessage
	Output OutputF
}

type Action interface {
	Run(config Config, params json.RawMessage, output OutputF) error
	Name() string
}

type BatchAction interface {
	Action
	RunMany(config Config, actionIOs []ActionIO) error
}
