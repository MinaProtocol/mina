package itn_orchestrator

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"itn_json_types"
	"os"

	"github.com/btcsuite/btcutil/base58"
	logging "github.com/ipfs/go-log/v2"
	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/nacl/secretbox"
)

type boxValue []byte

func (v *boxValue) UnmarshalJSON(data []byte) error {
	if data[0] == '"' && data[len(data)-1] == '"' {
		encoded := string(data[1 : len(data)-1])
		decoded, version, err := base58.CheckDecode(encoded)
		if err != nil {
			return err
		}
		if version != '\x02' {
			return errors.New("wrong version byte")
		}
		*v = decoded
		return nil
	}
	return errors.New("not a string token")
}

type limits struct {
	Mem uint32
	Ops uint32
}

func (v *limits) UnmarshalJSON(data []byte) error {
	var l []uint32
	err := json.Unmarshal(data, &l)
	if err != nil {
		return err
	}
	if len(l) != 2 {
		return errors.New("wrong limits format")
	}
	*v = limits{Mem: l[0], Ops: l[1]}
	return nil
}

type secretBox struct {
	Box_primitive string
	Pw_primitive  string
	Nonce         boxValue
	Pwsalt        boxValue
	Ciphertext    boxValue
	Pwdiff        limits
}

type KeyloaderParams struct {
	Dir         string `json:"dir"`
	Limit       int    `json:"limit,omitempty"`
	PasswordEnv string `json:"passwordEnv,omitempty"`
}

func LoadPrivateKey(fname string, password []byte) ([]byte, error) {
	jsonFile, err := os.Open(fname)
	if err != nil {
		return nil, fmt.Errorf("failed to open keyfile %s: %v", fname, err)
	}
	defer jsonFile.Close()
	bs, err := io.ReadAll(jsonFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read keyfile %s: %v", fname, err)
	}
	sk, err := DecodePrivateKey(bs, password)
	if err != nil {
		return nil, errors.Join(err, fmt.Errorf("failed decoding private key from file %s", fname))
	}
	return sk, nil
}

func DecodePrivateKey(bs []byte, password []byte) ([]byte, error) {
	var box secretBox
	json.Unmarshal(bs, &box)
	if box.Box_primitive != "xsalsa20poly1305" || box.Pw_primitive != "argon2i" {
		return nil, errors.New("unknown primitive type")
	}
	k := argon2.Key(password, box.Pwsalt, box.Pwdiff.Ops, box.Pwdiff.Mem/1024, 1, 32)
	var key [32]byte
	copy(key[:], k)
	var nonce [24]byte
	copy(nonce[:], box.Nonce)
	sk, opened := secretbox.Open(nil, box.Ciphertext, &nonce, &key)
	if !opened {
		return nil, errors.New("failed to unseal key")
	}
	return sk, nil
}

func LoadPrivateKeyFiles(log logging.StandardLogger, params KeyloaderParams, output func(itn_json_types.MinaPrivateKey)) error {
	var password []byte
	if params.PasswordEnv != "" {
		pass, has := os.LookupEnv(params.PasswordEnv)
		if has {
			password = []byte(pass)
		}
	}
	keyfiles, err := listKeyfiles(params.Dir)
	if err != nil {
		return err
	}
	for i, keyfile := range keyfiles {
		sk, err := LoadPrivateKey(keyfile, password)
		if err != nil {
			return err
		}
		sender := base58.CheckEncode(sk, '\x5A')
		output(itn_json_types.MinaPrivateKey(sender))
		if params.Limit > 0 && i+1 >= params.Limit {
			break
		}
	}
	return nil
}

type KeyloaderAction struct{}

func (KeyloaderAction) Name() string { return "load-keys" }
func (KeyloaderAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params KeyloaderParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return LoadPrivateKeyFiles(config.Log, params, func(sk itn_json_types.MinaPrivateKey) {
		output("key", sk, true, true)
	})
}

var _ Action = KeyloaderAction{}
