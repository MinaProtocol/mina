package main

import (
	"codanet"
	"context"
	crand "crypto/rand"
	"fmt"
	"io/ioutil"
	"sync"
	"testing"
	"time"

	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-pubsub"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/stretchr/testify/require"
)

func newTestKey(t *testing.T) crypto.PrivKey {
	r := crand.Reader
	key, _, err := crypto.GenerateEd25519Key(r)
	require.NoError(t, err)

	return key
}

func newTestApp(t *testing.T, seeds []peer.AddrInfo) *app {
	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	helper, err := codanet.MakeHelper(context.Background(),
		[]ma.Multiaddr{},
		nil,
		dir,
		newTestKey(t),
		"/mina/",
		seeds,
		codanet.NewCodaGatingState(nil, nil, nil),
	)
	require.NoError(t, err)

	return &app{
		P2p:            helper,
		Ctx:            context.Background(),
		Subs:           make(map[int]subscription),
		Topics:         make(map[string]*pubsub.Topic),
		ValidatorMutex: &sync.Mutex{},
		Validators:     make(map[int]*validationStatus),
		Streams:        make(map[int]net.Stream),
		AddedPeers:     make([]peer.AddrInfo, 0, 512),
	}
}

func addrInfos(h host.Host) (addrInfos []peer.AddrInfo, err error) {
	for _, multiaddr := range multiaddrs(h) {
		addrInfo, err := peer.AddrInfoFromP2pAddr(multiaddr)
		if err != nil {
			return nil, err
		}
		addrInfos = append(addrInfos, *addrInfo)
	}
	return addrInfos, nil
}

func multiaddrs(h host.Host) (multiaddrs []ma.Multiaddr) {
	addrs := h.Addrs()
	for _, addr := range addrs {
		multiaddr, err := ma.NewMultiaddr(fmt.Sprintf("%s/p2p/%s", addr, h.ID()))
		if err != nil {
			continue
		}
		multiaddrs = append(multiaddrs, multiaddr)
	}
	return multiaddrs
}

func TestDHTDiscovery(t *testing.T) {
	appA := newTestApp(t, nil)
	appA.NoMDNS = true
	defer appA.P2p.Host.Close()

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	appB.NoMDNS = true
	defer appB.P2p.Host.Close()

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, appAInfos)
	appC.NoMDNS = true
	defer appC.P2p.Host.Close()

	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	time.Sleep(time.Millisecond * 100)

	// begin appB and appC's DHT advertising
	ret, err := new(beginAdvertisingMsg).run(appB)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	ret, err = new(beginAdvertisingMsg).run(appC)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	time.Sleep(time.Second * 7)

	// check if peerB knows about peerC
	ids := appB.P2p.Host.Peerstore().PeersWithAddrs()
	for _, id := range ids {
		if id == appC.P2p.Host.ID() {
			return
		}
	}

	t.Fatal("B did not discover C via DHT")
}

func TestMDNSDiscovery(t *testing.T) {
	appA := newTestApp(t, nil)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()

	appB := newTestApp(t, nil)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// begin appB and appC's DHT advertising
	ret, err := new(beginAdvertisingMsg).run(appB)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	ret, err = new(beginAdvertisingMsg).run(appA)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	time.Sleep(time.Second * 2)

	// check if peerB knows about peerA
	ids := appB.P2p.Host.Peerstore().PeersWithAddrs()
	for _, id := range ids {
		if id == appA.P2p.Host.ID() {
			return
		}
	}

	t.Fatal("B did not discover A via mDNS")
}

func TestMplex_SendLargeMessage(t *testing.T) {
	// assert we are able to send and receive a message with size up to 1 << 30 bytes
}
