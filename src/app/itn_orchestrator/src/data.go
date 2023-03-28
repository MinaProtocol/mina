package itn_orchestrator

type MetaToBeSaved struct {
	CreatedAt          string `json:"created_at"`
	PeerId             string `json:"peer_id"`
	SnarkWork          string `json:"snark_work,omitempty"`
	GraphqlControlPort uint16 `json:"graphql_control_port,omitempty"`
	RemoteAddr         string `json:"remote_addr"`
	Submitter          string `json:"submitter"`  // is base58check-encoded submitter's public key
	BlockHash          string `json:"block_hash"` // is base58check-encoded hash of a block
}
