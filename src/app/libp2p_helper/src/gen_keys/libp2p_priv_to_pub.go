package main

import (
	crypto "github.com/libp2p/go-libp2p-crypto"
	"encoding/base64"
	"os"
)

func main() {
	if len(os.Args) != 2 {
		println("usage: libp2p-priv-to-pub PRIVKEY_BASE64_STRING")
	}
	privkEnc := os.Args[1]
	privkRaw, err := base64.Decode(privkEnc)
	if err != nil {
		panic(err)
	}

	priv, err := crypto.UnmarshalPrivateKey(privkRaw)
	if err != nil {
		panic(err)
	}

	pub := priv.GetPublic()

	pubkRaw, err := crypto.MarshalPublicKey(pub)
	if err != nil {
		panic(err)
	}

	pubkEnc := base64.Encode(pubkRaw)

	println(pubkEnc)
}
