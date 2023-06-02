package delegation_backend

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/btcsuite/btcutil/base58"
	"golang.org/x/crypto/blake2b"
)

type submitRequestDataV1 struct {
	submitRequestDataV0
	BuiltWithCommitSha string `json:"built_with_commit_sha"`
}
type submitRequestV1 struct {
	Data submitRequestDataV1 `json:"data"`
	submitRequestSubmitterSig
}

type MetaToBeSavedV1 struct {
	MetaToBeSavedV0
	BuiltWithCommitSha string `json:"built_with_commit_sha"`
}

func (req submitRequestV1) GetSubmitter() Pk {
	return req.Submitter
}

func (req submitRequestV1) GetSig() Sig {
	return req.Sig
}

func (req submitRequestV1) GetBlockDataHash() string {
	blockHashBytes := blake2b.Sum256(req.Data.Block.data)
	return base58.CheckEncode(blockHashBytes[:], BASE58CHECK_VERSION_BLOCK_HASH)
}

func (r submitRequestV1) MakeSignPayload() ([]byte, error) {
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

func (req submitRequestV1) GetCreatedAt() time.Time {
	return req.Data.CreatedAt
}

func (req submitRequestV1) MakeMetaToBeSaved(remoteAddr string) ([]byte, error) {
	meta := MetaToBeSavedV1{
		MetaToBeSavedV0: MetaToBeSavedV0{
			CreatedAt:          req.Data.CreatedAt.Format(time.RFC3339),
			PeerId:             req.Data.PeerId,
			SnarkWork:          req.Data.SnarkWork,
			RemoteAddr:         remoteAddr,
			BlockHash:          req.GetBlockDataHash(),
			Submitter:          req.Submitter,
			GraphqlControlPort: req.Data.GraphqlControlPort},
		BuiltWithCommitSha: req.Data.BuiltWithCommitSha,
	}

	return json.Marshal(meta)
}

func (req submitRequestV1) CheckRequiredFields() bool {
	return req.Data.BuiltWithCommitSha != "" && req.Data.Block != nil && req.Data.PeerId != "" && req.Data.CreatedAt != nilTime && req.Submitter != nilPk && req.Sig != nilSig
}

func (req submitRequestV1) GetBlockData() []byte {
	return req.Data.Block.data
}
