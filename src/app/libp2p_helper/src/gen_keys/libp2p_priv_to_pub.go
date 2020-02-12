package main

import (
	crypto "github.com/libp2p/go-libp2p-crypto"
	b58 "github.com/mr-tron/base58/base58"
	"os"
)

func main() {
	if len(os.Args) != 2 {
		println("usage: libp2p-priv-to-pub PRIVKEY_BASE58_STRING")
	}
	privk_enc := os.Args[1]
	privk_raw, err := b58.Decode(privk_enc)
	if err != nil {
		panic(err)
	}

	priv, err := crypto.UnmarshalPrivateKey(privk_raw)
	if err != nil {
		panic(err)
	}

	pub := priv.GetPublic()

	pubk_raw, err := crypto.MarshalPublicKey(pub)
	if err != nil {
		panic(err)
	}

	pubk_enc := b58.Encode(pubk_raw)

	println(pubk_enc)
}
