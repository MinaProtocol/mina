package delegation_backend

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/btcsuite/btcutil/base58"
	"golang.org/x/crypto/blake2b"
)

// Just a different interface for Unmarshal
func JSONToString(b []byte) (s string, err error) {
	err = json.Unmarshal(b, &s)
	return
}
func StringToPk(pk *Pk, s string) error {
	bs, ver, err := base58.CheckDecode(s)
	if err == nil && ver != BASE58CHECK_VERSION_PK {
		return errors.New("unexpected base58check version for Pk")
	}
	if err == nil {
		prefixLen := len(PK_PREFIX)
		if len(bs) == PK_LENGTH+prefixLen {
			if bytes.Equal(bs[:prefixLen], PK_PREFIX[:]) {
				copy(pk[:], bs[prefixLen:])
			} else {
				err = errors.New("unexpected prefix of Pk")
			}
		} else {
			err = fmt.Errorf("public key of an unexpected size %d", len(bs))
		}
	}
	return err
}
func StringToSig(sig *Sig, s string) error {
	bs, ver, err := base58.CheckDecode(s)
	if err == nil && ver != BASE58CHECK_VERSION_SIG {
		return errors.New("unexpected base58check version for Sig")
	}
	if err == nil {
		prefixLen := len(SIG_PREFIX)
		if len(bs) == SIG_LENGTH+prefixLen {
			if bytes.Equal(bs[:prefixLen], SIG_PREFIX[:]) {
				copy(sig[:], bs[prefixLen:])
			} else {
				err = errors.New("unexpected prefix of signature")
			}
		} else {
			err = fmt.Errorf("signature of an unexpected size %d", len(bs))
		}
	}
	return err
}

type Sig [SIG_LENGTH]byte

func (sig *Sig) UnmarshalJSON(b []byte) error {
	s, err := JSONToString(b)
	if err == nil {
		err = StringToSig(sig, s)
	}
	return err
}
func (d Sig) MarshalJSON() ([]byte, error) {
	return json.Marshal(base58.CheckEncode(append(SIG_PREFIX[:], d[:]...), BASE58CHECK_VERSION_SIG))
}

type Pk [PK_LENGTH]byte

func (pk *Pk) UnmarshalJSON(b []byte) error {
	s, err := JSONToString(b)
	if err == nil {
		err = StringToPk(pk, s)
	}
	return err
}
func (pk Pk) MarshalJSON() ([]byte, error) {
	return json.Marshal(pk.String())
}
func (pk Pk) Format() string {
	return pk.String()
}
func (pk Pk) String() string {
	return base58.CheckEncode(append(PK_PREFIX[:], pk[:]...), BASE58CHECK_VERSION_PK)
}

type Base64 struct {
	data []byte
	json []byte
}

func (d *Base64) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return err
	}
	bs, err := base64.StdEncoding.DecodeString(s)
	if err == nil {
		d.data = bs
		d.json = b
	}
	return err
}
func (d *Base64) MarshalJSON() ([]byte, error) {
	return d.json, nil
}

type BufferOrError struct {
	Buf bytes.Buffer
	Err error
}

func (boe *BufferOrError) WriteString(s string) {
	if boe.Err == nil {
		_, err := boe.Buf.WriteString(s)
		boe.Err = err
	}
}

func (boe *BufferOrError) Write(b []byte) {
	if boe.Err == nil {
		_, err := boe.Buf.Write(b)
		boe.Err = err
	}
}

type MetaToBeSaved struct {
	CreatedAt          string  `json:"created_at"`
	PeerId             string  `json:"peer_id"`
	SnarkWork          *Base64 `json:"snark_work,omitempty"`
	RemoteAddr         string  `json:"remote_addr"`
	Submitter          Pk      `json:"submitter"`  // is base58check-encoded submitter's public key
	BlockHash          string  `json:"block_hash"` // is base58check-encoded hash of a block
	GraphqlControlPort int     `json:"graphql_control_port,omitempty"`
	BuiltWithCommitSha string  `json:"built_with_commit_sha,omitempty"`
}

type submitRequestData struct {
	PeerId             string    `json:"peer_id"`
	Block              *Base64   `json:"block"`
	SnarkWork          *Base64   `json:"snark_work,omitempty"`
	CreatedAt          time.Time `json:"created_at"`
	GraphqlControlPort int       `json:"graphql_control_port,omitempty"`
	BuiltWithCommitSha string    `json:"built_with_commit_sha,omitempty"`
}
type submitRequest struct {
	Submitter Pk                `json:"submitter"`
	Sig       Sig               `json:"signature"`
	Data      submitRequestData `json:"data"`
}

func (req submitRequest) GetBlockDataHash() string {
	blockHashBytes := blake2b.Sum256(req.Data.Block.data)
	return base58.CheckEncode(blockHashBytes[:], BASE58CHECK_VERSION_BLOCK_HASH)
}

func (req submitRequestData) MakeSignPayload() ([]byte, error) {
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
	if req.BuiltWithCommitSha != "" {
		signPayload.WriteString(",\"built_with_commit_sha\":\"")
		signPayload.WriteString(req.BuiltWithCommitSha)
		signPayload.WriteString("\"")
	}
	signPayload.WriteString("}")
	return signPayload.Buf.Bytes(), signPayload.Err
}

func (req submitRequest) MakeMetaToBeSaved(remoteAddr string) ([]byte, error) {
	meta := MetaToBeSaved{
		CreatedAt:          req.Data.CreatedAt.Format(time.RFC3339),
		PeerId:             req.Data.PeerId,
		SnarkWork:          req.Data.SnarkWork,
		RemoteAddr:         remoteAddr,
		BlockHash:          req.GetBlockDataHash(),
		Submitter:          req.Submitter,
		GraphqlControlPort: req.Data.GraphqlControlPort,
		BuiltWithCommitSha: req.Data.BuiltWithCommitSha,
	}

	return json.Marshal(meta)
}

func (req submitRequest) CheckRequiredFields() bool {
	return req.Data.Block != nil && req.Data.PeerId != "" &&
		req.Data.CreatedAt != nilTime && req.Submitter != nilPk && req.Sig != nilSig
}
