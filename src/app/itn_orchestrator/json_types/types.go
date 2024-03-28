package itn_json_types

import (
	"crypto/ed25519"
	"encoding/base64"
	"errors"
	"strconv"
	"time"
)

type MinaPublicKey string
type MinaPrivateKey string

func UnmarshalUint64(data []byte, v *uint64) error {
	if data[0] == '"' && data[len(data)-1] == '"' {
		res, err := strconv.ParseUint(string(data[1:len(data)-1]), 10, 64)
		if err != nil {
			return err
		}
		*v = res
		return nil
	}
	return errors.New("not a string token")
}

func encloseInQuotes(s string) []byte {
	return append(append([]byte{'"'}, s...), byte('"'))
}

func MarshalUint64(v *uint64) ([]byte, error) {
	return encloseInQuotes(strconv.FormatUint(*v, 10)), nil
}

func UnmarshalUint16(data []byte, v *uint16) error {
	if data[0] == '"' && data[len(data)-1] == '"' {
		res, err := strconv.ParseUint(string(data[1:len(data)-1]), 10, 16)
		if err != nil {
			return err
		}
		*v = uint16(res)
		return nil
	}
	return errors.New("not a string token")
}

func MarshalUint16(v *uint16) ([]byte, error) {
	return encloseInQuotes(strconv.FormatUint(uint64(*v), 10)), nil
}

func UnmarshalBase64(data []byte, v *[]byte) error {
	if data[0] == '"' && data[len(data)-1] == '"' {
		res, err := base64.StdEncoding.DecodeString(string(data[1 : len(data)-1]))
		if err != nil {
			return err
		}
		*v = res
		return nil
	}
	return errors.New("not a string token")
}

func MarshalBase64(v *[]byte) ([]byte, error) {
	return encloseInQuotes(base64.StdEncoding.EncodeToString(*v)), nil
}

type Ed25519Privkey ed25519.PrivateKey

func (v *Ed25519Privkey) UnmarshalJSON(data []byte) error {
	var b []byte
	if err := UnmarshalBase64(data, &b); err != nil {
		return err
	}
	if len(b) != ed25519.SeedSize {
		return errors.New("wrong size of Private key")
	}
	*v = Ed25519Privkey(ed25519.NewKeyFromSeed(b))
	return nil
}

func (v *Ed25519Privkey) MarshalJSON() ([]byte, error) {
	seed := ed25519.PrivateKey(*v).Seed()
	return MarshalBase64(&seed)
}

type Time time.Time

func (v *Time) UnmarshalJSON(data []byte) error {
	if data[0] == '"' && data[len(data)-1] == '"' {
		res, err := time.Parse(time.RFC3339, string(data[1:len(data)-1]))
		if err != nil {
			return err
		}
		*v = Time(res)
		return nil
	}
	return errors.New("not a string token")
}

func (v *Time) MarshalJSON() ([]byte, error) {
	return []byte("\"" + time.Time(*v).Format(time.RFC3339) + "\""), nil
}

// func UnmarshalPublicKey(data []byte, v *ed25519.PublicKey) error {
// 	var b []byte
// 	if err := UnmarshalBase64(data, &b); err != nil {
// 		return err
// 	}
// 	if len(b) != ed25519.PublicKeySize {
// 		return errors.New("wrong size of Public key")
// 	}
// 	*v = ed25519.PublicKey(b)
// 	return nil
// }

// func MarshalPublicKey(v *ed25519.PublicKey) ([]byte, error) {
// 	a := []byte(*v)
// 	return MarshalBase64(&a)
// }
