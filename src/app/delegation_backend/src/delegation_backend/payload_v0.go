package delegation_backend

import (
	"encoding/json"
	"time"

	"github.com/btcsuite/btcutil/base58"
	"golang.org/x/crypto/blake2b"
)

type submitRequestDataV0 struct {
	PeerId    string    `json:"peer_id"`
	Block     *Base64   `json:"block"`
	SnarkWork *Base64   `json:"snark_work,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type submitRequestV0 struct {
	submitRequestCommon
	Data submitRequestDataV0 `json:"data"`
}

func (req submitRequestDataV0) GetBlockDataHash() string {
	blockHashBytes := blake2b.Sum256(req.Block.data)
	return base58.CheckEncode(blockHashBytes[:], BASE58CHECK_VERSION_BLOCK_HASH)
}

func (req submitRequestDataV0) MakeSignPayload() ([]byte, error) {
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
	signPayload.WriteString("}")
	return signPayload.Buf.Bytes(), signPayload.Err
}

func (req submitRequestDataV0) GetCreatedAt() time.Time {
	return req.CreatedAt
}

func (req submitRequestV0) MakeMetaToBeSaved(remoteAddr string) ([]byte, error) {
	meta := MetaToBeSaved{
		CreatedAt:  req.Data.CreatedAt.Format(time.RFC3339),
		PeerId:     req.Data.PeerId,
		SnarkWork:  req.Data.SnarkWork,
		RemoteAddr: remoteAddr,
		BlockHash:  req.Data.GetBlockDataHash(),
		Submitter:  req.Submitter,
	}

	return json.Marshal(meta)
}

func (req submitRequestV0) CheckRequiredFields() bool {
	return req.Data.Block != nil && req.Data.PeerId != "" && req.Data.CreatedAt != nilTime && req.Submitter != nilPk && req.Sig != nilSig
}

func (req submitRequestDataV0) GetBlockData() []byte {
	return req.Block.data
}

func (req submitRequestV0) GetSig() Sig {
	return req.Sig
}
func (req submitRequestV0) GetSubmitter() Pk {
	return req.Submitter
}

func (req submitRequestV0) GetData() submitRequestData {
	return req.Data
}

func (req submitRequestV0) GetPayloadVersion() int {
	return req.PayloadVersion
}
