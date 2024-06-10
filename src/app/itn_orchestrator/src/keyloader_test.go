package itn_orchestrator

import (
	"testing"

	"github.com/btcsuite/btcutil/base58"
)

func TestDecodePrivateKey(t *testing.T) {
	skBoxed := []byte("{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"8p9B5WcoBtfKCFhLfurLPPUT9Kih5pH141hBYdK\",\"pwsalt\":\"98Q3JzhWcpGQFkyHs6khJUyY75Tx\",\"pwdiff\":[134217728,6],\"ciphertext\":\"AVehFg79QEYuEqdb5a3CqKgRctLAfCxeiJxmiwEA5rThVEazV1w5h6QJBCcBnMbZpgE28AiJF\"}")
	sk, err := DecodePrivateKey(skBoxed, nil)
	if err != nil {
		t.Fatal("failed to decode key")
	}
	if base58.CheckEncode(sk, '\x5A') != "EKEEpMELfQkMbJDt2fB4cFXKwSf1x4t7YD4twREy5yuJ84HBZtF9" {
		t.Fatal("unexpected key decoded")
	}
}
