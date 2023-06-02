package delegation_backend

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/btcsuite/btcutil/base58"
	"golang.org/x/crypto/blake2b"
)

type submitRequestDataV0 struct {
	PeerId             string    `json:"peer_id"`
	Block              *Base64   `json:"block"`
	SnarkWork          *Base64   `json:"snark_work,omitempty"`
	GraphqlControlPort uint16    `json:"graphql_control_port,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
}
type submitRequestV0 struct {
	Data submitRequestDataV0 `json:"data"`
	submitRequestSubmitterSig
}

type MetaToBeSavedV0 struct {
	CreatedAt          string  `json:"created_at"`
	PeerId             string  `json:"peer_id"`
	SnarkWork          *Base64 `json:"snark_work,omitempty"`
	GraphqlControlPort uint16  `json:"graphql_control_port,omitempty"`
	RemoteAddr         string  `json:"remote_addr"`
	Submitter          Pk      `json:"submitter"`  // is base58check-encoded submitter's public key
	BlockHash          string  `json:"block_hash"` // is base58check-encoded hash of a block
}

func (req submitRequestV0) GetSubmitter() Pk {
	return req.Submitter
}

func (req submitRequestV0) GetSig() Sig {
	return req.Sig
}

func (req submitRequestV0) GetBlockDataHash() string {
	blockHashBytes := blake2b.Sum256(req.Data.Block.data)
	return base58.CheckEncode(blockHashBytes[:], BASE58CHECK_VERSION_BLOCK_HASH)
}

func (r submitRequestV0) MakeSignPayload() ([]byte, error) {
	req := &r.Data
	createdAtStr := req.CreatedAt.UTC().Format(time.RFC3339)
	createdAtJson, err2 := json.Marshal(createdAtStr)
	if err2 != nil {
		return nil, err2
	}
	signPayload := new(BufferOrError)
	signPayload.WriteString("{\"block\":")
	signPayload.Write(req.Block.json)
	signPayload.WriteString(",\"created_at\":")
	signPayload.Write(createdAtJson)
	signPayload.WriteString(",\"peer_id\":\"")
	signPayload.WriteString(req.PeerId)
	signPayload.WriteString("\"")
	if req.SnarkWork != nil {
		signPayload.WriteString(",\"snark_work\":")
		signPayload.Write(req.SnarkWork.json)
	}
	if req.GraphqlControlPort != 0 {
		signPayload.WriteString(",\"graphql_control_port\":")
		signPayload.WriteString(fmt.Sprintf("%d", req.GraphqlControlPort))
	}
	signPayload.WriteString("}")
	return signPayload.Buf.Bytes(), signPayload.Err
}

func (req submitRequestV0) GetCreatedAt() time.Time {
	return req.Data.CreatedAt
}

func (req submitRequestV0) MakeMetaToBeSaved(remoteAddr string) ([]byte, error) {
	meta := MetaToBeSavedV0{
		CreatedAt:          req.Data.CreatedAt.Format(time.RFC3339),
		PeerId:             req.Data.PeerId,
		SnarkWork:          req.Data.SnarkWork,
		RemoteAddr:         remoteAddr,
		BlockHash:          req.GetBlockDataHash(),
		Submitter:          req.Submitter,
		GraphqlControlPort: req.Data.GraphqlControlPort,
	}

	return json.Marshal(meta)
}

func (req submitRequestV0) CheckRequiredFields() bool {
	return req.Data.Block != nil && req.Data.PeerId != "" && req.Data.CreatedAt != nilTime && req.Submitter != nilPk && req.Sig != nilSig
}

func (req submitRequestV0) GetBlockData() []byte {
	return req.Data.Block.data
}
