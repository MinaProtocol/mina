module codanet

go 1.16

require (
	capnproto.org/go/capnp/v3 v3.0.0-alpha.1
	github.com/georgeee/go-bs-lmdb v1.0.6-0.20211007111842-a06db2e6401e
	github.com/go-errors/errors v1.4.1
	github.com/ipfs/go-bitswap v0.4.0
	github.com/ipfs/go-block-format v0.0.3
	github.com/ipfs/go-cid v0.0.7
	github.com/ipfs/go-ds-badger v0.2.7
	github.com/ipfs/go-ipfs-blockstore v1.0.3
	github.com/ipfs/go-ipfs-exchange-interface v0.0.1
	github.com/ipfs/go-log/v2 v2.3.0
	github.com/libp2p/go-libp2p v0.15.1
	github.com/libp2p/go-libp2p-connmgr v0.2.4
	github.com/libp2p/go-libp2p-core v0.9.0
	github.com/libp2p/go-libp2p-discovery v0.5.1
	github.com/libp2p/go-libp2p-kad-dht v0.13.1
	github.com/libp2p/go-libp2p-kbucket v0.4.7
	github.com/libp2p/go-libp2p-mplex v0.4.1
	github.com/libp2p/go-libp2p-peerstore v0.3.0
	github.com/libp2p/go-libp2p-pubsub v0.5.4
	github.com/libp2p/go-libp2p-record v0.1.3
	github.com/libp2p/go-mplex v0.3.0
	github.com/multiformats/go-multiaddr v0.4.1
	github.com/multiformats/go-multihash v0.0.15
	github.com/prometheus/client_golang v1.11.0
	github.com/shirou/gopsutil/v3 v3.21.11
	github.com/stretchr/testify v1.7.0
	golang.org/x/crypto v0.0.0-20210921155107-089bfa567519
	libp2p_ipc v0.0.0
)

replace libp2p_ipc => ../../../libp2p_ipc
replace github.com/libp2p/go-libp2p-connmgr => ../../../external/go-libp2p-connmgr
