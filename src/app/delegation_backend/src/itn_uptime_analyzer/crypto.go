package itn_uptime_analyzer

import (
	"crypto/md5"
	"encoding/hex"
	"strings"
)

type Identity map[string]string

func GetIdentity(pubKey string, ip string) map[string]string {
	s := strings.Join([]string{pubKey, ip}, "-")
	id := md5.Sum([]byte(s)) // Create a hash value and use it as id

	identity := map[string]string{
		"id": hex.EncodeToString(id[:]),
		"public-key": pubKey,
		"public-ip": ip,
	}

	return identity
}

func AddIdentity(identity Identity, identities map[string]Identity) {
	identities[identity["id"]] = identity
}