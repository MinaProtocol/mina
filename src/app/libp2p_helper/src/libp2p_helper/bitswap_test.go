package main

import (
	"bytes"
	"codanet"
	"context"
	"errors"
	"fmt"
	"io/ioutil"
	ipc "libp2p_ipc"
	"math/rand"
	"reflect"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"testing/quick"
	"time"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/ipfs/go-cid"
	blockstore "github.com/ipfs/go-ipfs-blockstore"
	logging "github.com/ipfs/go-log/v2"
	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/peer"
	kb "github.com/libp2p/go-libp2p-kbucket"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	multihash "github.com/multiformats/go-multihash"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/blake2b"
)

const REQS_PER_NODE = 5

// TODO use CONNS_LO = 2
const CONNS_LO = 2
const CONNS_HI = CONNS_LO + REQS_PER_NODE

const NUM_NODES = 15

type bitswapTestNodeParams struct {
	resource  []byte
	requests1 [REQS_PER_NODE]int
	requests2 [REQS_PER_NODE]int
}
type bitswapTestAttempt [NUM_NODES]bitswapTestNodeParams
type bitswapTestConfig []bitswapTestAttempt
type testNode struct {
	node *app
	trap *upcallTrap
}

func initBitswapTestConfig(r *rand.Rand, numAttempts, maxBlobSize int) bitswapTestConfig {
	conf := make([]bitswapTestAttempt, numAttempts)
	for ai := range conf {
		for ni := range conf[ai] {
			n := &conf[ai][ni]
			n.resource = make([]byte, r.Intn(maxBlobSize)+100)
			r.Read(n.resource)
			for ri := range n.requests1 {
				n.requests1[ri] = r.Intn(NUM_NODES)
				n.requests2[ri] = r.Intn(NUM_NODES)
			}
		}
	}
	return conf
}

func (bitswapTestConfig) Generate(r *rand.Rand, size int) reflect.Value {
	return reflect.ValueOf(initBitswapTestConfig(r, 1, size))
}

func getRootIds(ids ipc.RootBlockId_List) ([]BitswapBlockLink, error) {
	links := make([]BitswapBlockLink, ids.Len())
	for i := 0; i < ids.Len(); i++ {
		rootId := ids.At(i)
		root_, err := rootId.Blake2bHash()
		if err != nil {
			return nil, err
		}
		var link BitswapBlockLink
		if len(root_) == len(link) {
			copy(link[:], root_)
			links[i] = link
		} else {
			return nil, errors.New("Unexpected length of root block id")
		}
	}
	return links, nil
}

func removeOwn(nodes [NUM_NODES]testNode, nodeRoots [NUM_NODES]BitswapBlockLink) error {
	for ni, n := range nodes {
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		if err != nil {
			return err
		}
		m, err := ipc.NewRootLibp2pHelperInterface_DeleteResource(seg)
		if err != nil {
			return err
		}
		ids, err := m.NewIds(1)
		if err != nil {
			return err
		}
		err = ids.At(0).SetBlake2bHash(nodeRoots[ni][:])
		if err != nil {
			return err
		}
		DeleteResourcePush(m).handle(n.node)
	}
	return nil
}

func awaitRemoval(nodes [NUM_NODES]testNode, nodeRoots [NUM_NODES]BitswapBlockLink) (err error) {
	success := withCustomTimeout(func() {
		setResUpdErr := func(s string, args ...interface{}) {
			err = fmt.Errorf("Unexpected ResourceUpdate on remove: "+s, args...)
		}
		for ni, n := range nodes {
			m, received := <-n.trap.ResourceUpdate
			if !received {
				err = errors.New("resourceUpdate trap closed")
				return
			}
			if m.Type() != ipc.ResourceUpdateType_removed {
				setResUpdErr("wrong type %d", m.Type())
				return
			}
			var ids ipc.RootBlockId_List
			ids, err = m.Ids()
			if err != nil {
				return
			}
			var ids_ []BitswapBlockLink
			ids_, err = getRootIds(ids)
			if err != nil {
				return
			}
			if len(ids_) != 1 || !bytes.Equal(ids_[0][:], nodeRoots[ni][:]) {
				setResUpdErr("wrong ids")
				return
			}
		}
	}, time.Second*30)
	if err == nil && !success {
		err = errors.New("timeout waiting for ResourceUpdate on resource removal")
	}
	return
}

func (at *bitswapTestAttempt) publish(nodes [NUM_NODES]testNode) error {
	for ni, nconf := range at {
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		if err != nil {
			return err
		}
		m, err := ipc.NewRootLibp2pHelperInterface_AddResource(seg)
		m.SetData(nconf.resource)
		if err != nil {
			return err
		}
		AddResourcePush(m).handle(nodes[ni].node)
	}
	return nil
}

func (at *bitswapTestAttempt) awaitPublish(nodes [NUM_NODES]testNode) (resIds [NUM_NODES]BitswapBlockLink, err error) {
	success := withCustomTimeout(func() {
		resUpdErr := errors.New("Unexpected ResourceUpdate on publish")
		for ni, nconf := range at {
			n := nodes[ni]
			m, received := <-n.trap.ResourceUpdate
			if !received {
				err = errors.New("ResourceUpdate trap closed")
				return
			}
			if m.Type() != ipc.ResourceUpdateType_added {
				err = resUpdErr
				return
			}
			data := nconf.resource
			_, root := SplitDataToBitswapBlocksLengthPrefixedWithTag(n.node.bitswapCtx.maxBlockSize, data, BlockBodyTag)
			resIds[ni] = root
			var ids ipc.RootBlockId_List
			ids, err = m.Ids()
			if err != nil {
				return
			}
			var ids_ []BitswapBlockLink
			ids_, err = getRootIds(ids)
			if err != nil {
				return
			}
			if len(ids_) != 1 || !bytes.Equal(ids_[0][:], root[:]) {
				err = resUpdErr
				return
			}
		}
	}, time.Minute*7)
	if err == nil && !success {
		err = errors.New("Timeout waiting for ResourceUpdate on resource publish")
	}
	return
}

func confirmBlocksNotInStorage(bs *BitswapCtx, resource []byte) error {
	blocks, _ := SplitDataToBitswapBlocksLengthPrefixedWithTag(bs.maxBlockSize, resource, BlockBodyTag)
	for h := range blocks {
		err := bs.storage.ViewBlock(h, func(actualB []byte) error {
			return nil
		})
		if err == nil {
			return fmt.Errorf("block %s wasn't deleted", codanet.BlockHashToCidSuffix(h))
		} else if err != blockstore.ErrNotFound {
			return err
		}
	}
	return nil
}

func confirmBlocksInStorage(bs *BitswapCtx, resource []byte) error {
	blocks, root := SplitDataToBitswapBlocksLengthPrefixedWithTag(bs.maxBlockSize, resource, BlockBodyTag)
	_, hasRootBlock := blocks[root]
	if !hasRootBlock {
		return fmt.Errorf("unexpected no root block")
	}
	for h, b := range blocks {
		err := bs.storage.ViewBlock(h, func(actualB []byte) error {
			if bytes.Equal(b, actualB) {
				return nil
			}
			return fmt.Errorf("wrong block body for %s", codanet.BlockHashToCidSuffix(h))
		})
		if err != nil {
			return err
		}
	}
	return nil
}
func (at *bitswapTestAttempt) requestResources(nodes [NUM_NODES]testNode, roots [NUM_NODES]BitswapBlockLink, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) (err error) {
	for ni, nconf := range at {
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		if err != nil {
			return err
		}
		m, err := ipc.NewRootLibp2pHelperInterface_DownloadResource(seg)
		if err != nil {
			return err
		}
		requests := getRequests(&nconf)
		ids, err := m.NewIds(int32(len(requests)))
		if err != nil {
			return err
		}
		m.SetTag(uint8(BlockBodyTag))
		for i, resId := range requests {
			err := ids.At(i).SetBlake2bHash(roots[resId][:])
			if err != nil {
				return err
			}
		}
		DownloadResourcePush(m).handle(nodes[ni].node)
	}
	return nil
}
func (at *bitswapTestAttempt) awaitResourceDownload(nodes [NUM_NODES]testNode, roots [NUM_NODES]BitswapBlockLink, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) (err error) {
	success := withCustomTimeout(func() {
		for ni, nconf := range at {
			setResUpdErr := func(s string, args ...interface{}) {
				err = fmt.Errorf("Unexpected ResourceUpdate on download: "+s, args...)
			}
			allIds := make(map[BitswapBlockLink]bool)
			remained := make(map[BitswapBlockLink]bool)
			for _, resId := range getRequests(&nconf) {
				allIds[roots[resId]] = true
				remained[roots[resId]] = true
			}
			for {
				if len(remained) == 0 {
					break
				}
				m, received := <-nodes[ni].trap.ResourceUpdate
				if !received {
					err = errors.New("ResourceUpdate trap closed")
					return
				}
				if m.Type() != ipc.ResourceUpdateType_added {
					setResUpdErr("unexpected type %d", m.Type())
					return
				}
				var ids ipc.RootBlockId_List
				ids, err = m.Ids()
				if err != nil {
					return
				}
				var ids_ []BitswapBlockLink
				ids_, err = getRootIds(ids)
				if err != nil {
					return
				}
				for _, id := range ids_ {
					if !allIds[id] {
						setResUpdErr("unexpected id %v", id)
						return
					}
					delete(remained, id)
				}
			}
		}
	}, time.Minute*7)
	if err == nil && !success {
		err = errors.New("Timeout waiting for ResourceUpdate on resource download")
	}
	return
}
func (at *bitswapTestAttempt) confirmResourceDownload(nodes [NUM_NODES]testNode, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) error {
	for ni, nconf := range at {
		bs := nodes[ni].node.bitswapCtx
		for _, resId := range getRequests(&nconf) {
			err := confirmBlocksInStorage(bs, at[resId].resource)
			if err != nil {
				return err
			}
		}
	}
	return nil
}

func (at *bitswapTestAttempt) downloadAndCheckResources(nodes [NUM_NODES]testNode, roots [NUM_NODES]BitswapBlockLink, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) (err error) {
	err = at.requestResources(nodes, roots, getRequests)
	if err != nil {
		return err
	}
	err = at.awaitResourceDownload(nodes, roots, getRequests)
	if err != nil {
		return err
	}
	err = at.confirmResourceDownload(nodes, getRequests)
	if err != nil {
		return err
	}
	return nil
}
func (conf bitswapTestConfig) execute(nodes [NUM_NODES]testNode) error {
	for _, at := range conf {
		err := at.publish(nodes)
		if err != nil {
			return err
		}
		roots, err := at.awaitPublish(nodes)
		if err != nil {
			return err
		}
		for ni, nconf := range at {
			bs := nodes[ni].node.bitswapCtx
			err = confirmBlocksInStorage(bs, nconf.resource)
			if err != nil {
				return err
			}
		}
		err = at.downloadAndCheckResources(nodes, roots, func(p *bitswapTestNodeParams) [REQS_PER_NODE]int {
			return p.requests1
		})
		if err != nil {
			return err
		}
		err = removeOwn(nodes, roots)
		if err != nil {
			return err
		}
		err = awaitRemoval(nodes, roots)
		if err != nil {
			return err
		}
		for ni, nconf := range at {
			bs := nodes[ni].node.bitswapCtx
			err = confirmBlocksNotInStorage(bs, nconf.resource)
			if err != nil {
				return err
			}
		}
		// TODO uncomment this
		// err = at.downloadAndCheckResources(nodes, roots, func(p *bitswapTestNodeParams) [REQS_PER_NODE]int {
		// 	return p.requests2
		// })
		// if err != nil {
		// 	return err
		// }
	}
	return nil
}

type randomTestBytes []byte

func (randomTestBytes) Generate(r *rand.Rand, size int) reflect.Value {
	b := make([]byte, r.Intn(size)+100)
	r.Read(b)
	return reflect.ValueOf(b)
}

func TestBitswapRootBlockCid(t *testing.T) {
	require.NotEqual(t, codanet.MULTI_HASH_CODE, uint64(0))
	f := func(b randomTestBytes) error {
		blocks, root := SplitDataToBitswapBlocks(1<<18, b)
		cid1 := codanet.BlockHashToCid(root)
		rootBody, has := blocks[root]
		if !has {
			return errors.New("Root not in blocks map")
		}
		hasher, err := multihash.GetHasher(codanet.MULTI_HASH_CODE)
		if err != nil {
			return errors.New("Couldn't construct a hasher")
		}
		hasher.Write(rootBody)
		h := hasher.Sum(nil)
		h2 := blake2b.Sum256(rootBody)
		if !bytes.Equal(h2[:], root[:]) {
			return fmt.Errorf("Invalid root hash calculation: %v != %v", h2, root)
		}
		if !bytes.Equal(h2[:], h[:]) {
			return fmt.Errorf("Hashes not equal: %v != %v", h2, h)
		}
		mh, _ := multihash.Encode(h, codanet.MULTI_HASH_CODE)
		cid2 := cid.NewCidV1(cid.Raw, mh)
		// err := c.execute(t, nodes)
		// return err == nil
		l1 := cid1.ByteLen()
		l2 := cid2.ByteLen()
		if l1 != l2 {
			return fmt.Errorf("Cid lengths differ: %d != %d", l1, l2)
		}
		if !bytes.Equal(cid2.Bytes(), cid1.Bytes()) {
			return errors.New("Cids not equal")
		}
		return nil
	}
	require.NoError(t, f([]byte{0}))
	if err := quick.Check(func(b randomTestBytes) bool {
		return f(b) == nil
	}, nil); err != nil {
		t.Error(err)
	}
}

func beginAdvertisingOnNodes(t *testing.T, nodes [NUM_NODES]testNode) {
	resultChan := make(chan *capnp.Message)
	_ = resultChan
	var resMsgErr error
	for ni := 0; ni < NUM_NODES; ni++ {
		node := nodes[ni].node
		// go func() {
		var resMsg *capnp.Message
		resMsg, err := beginAdvertisingSendAndCheckDo(node, 123)
		if err != nil {
			resMsgErr = err
		}
		node.P2p.Logger.Info("beginAdvertising: got response")
		// 	resultChan <- resMsg
		// 	// }()
		// }
		// for ni := 0; ni < NUM_NODES; ni++ {
		// 	resMsg := <-resultChan
		require.NoError(t, resMsgErr)
		checkBeginAdvertisingResponse(t, 123, resMsg)
	}
}

func testBitswapInitNodes(t *testing.T, upcallMask uint32) (nodes [NUM_NODES]testNode) {
	errChans := []chan error{}
	// TODO consider launching a process to monitor number of open connections
	done := make(chan interface{})
	var cancels [NUM_NODES]context.CancelFunc
	var keys [NUM_NODES]crypto.PrivKey
	var ids [NUM_NODES]kb.ID
	// We generate keys in such an awkward way to make dht not mark the peer ids as protected
	for ni := 0; ni < NUM_NODES; {
		keys[ni] = newTestKey(t)
		pid, err := peer.IDFromPrivateKey(keys[ni])
		require.NoError(t, err)
		ids[ni] = kb.ConvertPeerID(pid)
		if ni == 0 || kb.CommonPrefixLen(ids[ni], ids[0]) >= 2 {
			ni++
		}
	}
	for ni := 0; ni < NUM_NODES; ni++ {
		trap := newUpcallTrap(fmt.Sprintf("node %d", ni), 64, upcallMask)
		ctx, cancelF := context.WithCancel(context.Background())
		cancels[ni] = cancelF
		node := newTestAppWithMaxConnsAndCtx(t, keys[ni], nil, false, CONNS_LO, CONNS_HI, false, nextPort(), ctx)
		node.P2p.Logger = logging.Logger(fmt.Sprintf("node%d", ni))
		node.SetConnectionHandlers()
		errChan := launchFeedUpcallTrap(t, node.OutChan, trap, done)
		errChans = append(errChans, errChan)
		nodes[ni].node = node
		nodes[ni].trap = trap
		go node.bitswapCtx.Loop()
	}
	t.Cleanup(func() {
		close(done)
		for _, f := range cancels {
			f()
		}
		for _, errChan := range errChans {
			if err := <-errChan; err != nil {
				t.Errorf("TestBitswap failed with %s", err)
			}
		}
	})
	return nodes
}

func iteratePrevNextPeers(t *testing.T, nodes [NUM_NODES]testNode, f func(node testNode, prev, next peer.AddrInfo)) {
	for ni, node := range nodes {
		prevInfos, err := addrInfos(nodes[(ni-1+NUM_NODES)%NUM_NODES].node.P2p.Host)
		require.NoError(t, err)
		nextInfos, err := addrInfos(nodes[(ni+1)%NUM_NODES].node.P2p.Host)
		require.NoError(t, err)
		f(node, prevInfos[0], nextInfos[0])
	}

}

func connectRingTopology(t *testing.T, nodes [NUM_NODES]testNode, protect bool) {
	iteratePrevNextPeers(t, nodes, func(node testNode, prev, next peer.AddrInfo) {
		testAddPeerImplDo(t, node.node, next, true)
		// to ensure connectivity is not lost
		if protect {
			node.node.P2p.ConnectionManager.Protect(next.ID, "seed")
			node.node.P2p.ConnectionManager.Protect(prev.ID, "seed")
		}
	})
}

func testBroadcast(t *testing.T, nodes [NUM_NODES]testNode, senderIx int, timeout time.Duration) {
	nodes[senderIx].node.P2p.Logger.Infof("Sending broadcast message")
	msg := []byte("bla")
	testPublishDo(t, nodes[senderIx].node, "test", msg, 102)
	ctx, cancelF := context.WithTimeout(context.Background(), timeout)
	defer cancelF()
	counter := int32(NUM_NODES - 1)
	grError := make(chan error)
	for i, n := range nodes {
		if i == senderIx {
			continue
		}
		go func(n testNode) {
			select {
			case <-ctx.Done():
			case gr := <-n.trap.GossipReceived:
				err := func() error {
					bs, err := gr.Data()
					if err != nil {
						return err
					}
					if !bytes.Equal(bs, msg) {
						return fmt.Errorf("Unexpected gossip: %v", bs)
					}
					vid, err := gr.ValidationId()
					if err != nil {
						return err
					}
					_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
					if err != nil {
						return err
					}
					m, err := ipc.NewRootLibp2pHelperInterface_Validation(seg)
					if err != nil {
						return err
					}
					m.SetValidationId(vid)
					m.SetResult(ipc.ValidationResult_accept)
					ValidationPush(m).handle(n.node)
					return nil
				}()
				if err != nil {
					grError <- err
					return
				}
				nc := atomic.AddInt32(&counter, -1)
				if nc == 0 {
					cancelF()
				}
			}
		}(n)
	}
	select {
	case <-ctx.Done():
		require.Equal(t, context.Canceled, ctx.Err())
	case err := <-grError:
		t.Fatal(err)
	}
}

type MessageWithPeerId interface {
	PeerId() (ipc.PeerId, error)
}

func LogConnections(nodes [NUM_NODES]testNode, status map[int]map[int]bool, lock *sync.Mutex) context.CancelFunc {
	ctx, cancelF := context.WithCancel(context.Background())
	pidToIx := map[string]int{}
	// seds := []string{}
	for ni, n := range nodes {
		pid := n.node.P2p.Me.String()
		pidToIx[pid] = ni
		// seds = append(seds, fmt.Sprintf("sed 's/%s/node%d/g'", pid, ni))
	}
	// fmt.Println(strings.Join(seds, " | "))
	getIx := func(m MessageWithPeerId) (int, error) {
		pid_, err := m.PeerId()
		if err != nil {
			return -1, err
		}
		pid, err := pid_.Id()
		if err != nil {
			return -1, err
		}
		ix, has := pidToIx[pid]
		if !has {
			return 100, fmt.Errorf("unknown peer %s", pid)
		}
		return ix, nil
	}

	updateStatus := func(x, y int, st bool) (bool, int, int) {
		lock.Lock()
		defer lock.Unlock()
		if _, has := status[y]; !has {
			status[y] = make(map[int]bool)
		}
		if _, has := status[x]; !has {
			status[x] = make(map[int]bool)
		}
		st_, has := status[x][y]
		status[x][y] = st
		status[y][x] = st
		return !has || st_ != st, x, y
	}
	for ni, node := range nodes {
		ni_ := ni
		n := node
		go func() {
			for {
				select {
				case m := <-n.trap.PeerConnected:
					ix, err := getIx(m)
					if ok, x, y := updateStatus(ni_, ix, true); ok {
						n.node.P2p.Logger.Infof("%d ↔ %d %v", x, y, err)
					}
				case m := <-n.trap.PeerDisconnected:
					ix, err := getIx(m)
					if ok, x, y := updateStatus(ni_, ix, false); ok {
						n.node.P2p.Logger.Infof("%d ⊝ %d %v", x, y, err)
					}
				case <-ctx.Done():
					return
				}
			}
		}()
	}
	return cancelF
}

func printConnectionGraph(graph map[int]map[int]bool) {
	file, err := ioutil.TempFile("", "connections-*.dot")
	if err != nil {
		fmt.Println("Failed to create a tmp dot file")
		return
	}
	fmt.Printf("Writing to %s\n", file.Name())
	defer file.Close()
	file.WriteString(fmt.Sprintln("graph conns{"))
	for i, st := range graph {
		for j, has := range st {
			if j < i || !has {
				continue // print each edge only once, ignore false edges
			}
			file.WriteString(fmt.Sprintf("\tn%d -- n%d;\n", i, j))
		}
	}
	file.WriteString(fmt.Sprintln("}"))
}

func printPeers(nodes [NUM_NODES]testNode) {
	for _, n := range nodes {
		cm := n.node.P2p.ConnectionManager
		cm.ViewProtected(func(m map[peer.ID]map[string]interface{}) {
			for _, peer := range n.node.P2p.Host.Network().Peers() {
				pm, has := m[peer]
				protectedTags := []string{}
				if has {
					for tag := range pm {
						protectedTags = append(protectedTags, tag)
					}
				}
				info := cm.GetTagInfo(peer)
				n.node.P2p.Logger.Infof("%s protected:%s info:%v", peer, strings.Join(protectedTags, ","), info)
			}
		})
	}
}

func trimConnections(nodes [NUM_NODES]testNode) {
	for _, n := range nodes {
		connMgr := n.node.P2p.ConnectionManager
		n.node.P2p.Logger.Infof("connmgr status: %v", connMgr.GetInfo())
		connMgr.TrimOpenConns(context.Background())
		n.node.P2p.Logger.Infof("connmgr status after trimming: %v", connMgr.GetInfo())
	}
}

func checkConnectionGraph(t *testing.T, connectionGraph map[int]map[int]bool, expectConnected bool) {
	var visited [NUM_NODES]bool
	// BFS traversal of connection graph
	for nextIx := 0; nextIx < NUM_NODES; nextIx++ {
		if visited[nextIx] {
			continue
		}
		if nextIx > 0 && expectConnected {
			t.Errorf("Disconnected graph: at leats two roots 0 and %d", nextIx)
		}
		q := []int{nextIx}
		for ; len(q) > 0; q = q[1:] {
			n := q[0]
			if visited[n] {
				continue
			}
			visited[n] = true
			st, hasSt := connectionGraph[n]
			if !hasSt {
				continue
			}
			childCount := 0
			for m, c := range st {
				if !c {
					continue
				}
				childCount++
				q = append(q, m)
			}
			if childCount > CONNS_HI {
				t.Errorf("Node %d: %d connections exceed highwater %d", n, childCount, CONNS_HI)
			}
		}
	}
}

// TODO consider moving this function to other file
func TestBroadcastInNotFullConnectedNetwork(t *testing.T) {
	nodes := testBitswapInitNodes(t, upcallDropAllMask^(1<<GossipReceivedChan)^(1<<PeerConnectedChan)^(1<<PeerDisconnectedChan))
	// Connection graph is represented by map from node x to node y mapped to boolean (false entries are to be discraded)
	// invariant: connectionGraph[x][y] == connectionGraph[y][x]
	connectionGraph := make(map[int]map[int]bool)
	var lock sync.Mutex
	logCancel := LogConnections(nodes, connectionGraph, &lock)
	defer logCancel()
	// Parameters for mesh
	gossipSubp := pubsub.DefaultGossipSubParams()
	gossipSubp.D = 2
	gossipSubp.Dlo = 1
	gossipSubp.Dhi = 3
	iteratePrevNextPeers(t, nodes, func(n testNode, prev, next peer.AddrInfo) {
		configurePubsub(n.node, 100, []peer.AddrInfo{next, prev},
			pubsub.WithGossipSubParams(gossipSubp))
		testSubscribeDo(t, n.node, "test", 0, 101)
	})
	connectRingTopology(t, nodes, true)
	beginAdvertisingOnNodes(t, nodes)
	time.Sleep(11 * time.Second) // wait for network topology to stabilize
	trimConnections(nodes)
	lock.Lock()
	checkConnectionGraph(t, connectionGraph, true)
	if t.Failed() {
		printConnectionGraph(connectionGraph)
		printPeers(nodes)
	}
	lock.Unlock()
	r := rand.New(rand.NewSource(0))
	for i := 0; i < 3; i++ {
		time.Sleep(11 * time.Second)
		trimConnections(nodes)
		testBroadcast(t, nodes, r.Intn(len(nodes)), 2*time.Minute)
	}
}

const resourceUpdateOnlyMask = upcallDropAllMask ^ (1 << ResourceUpdateChan)

func TestBitswap(t *testing.T) {
	nodes := testBitswapInitNodes(t, resourceUpdateOnlyMask)
	connectRingTopology(t, nodes, true)
	beginAdvertisingOnNodes(t, nodes)
	conf := initBitswapTestConfig(rand.New(rand.NewSource(1)), 10, 1<<23)
	require.NoError(t, conf.execute(nodes))
}
func TestBitswapQC(t *testing.T) {
	nodes := testBitswapInitNodes(t, resourceUpdateOnlyMask)
	connectRingTopology(t, nodes, true)
	beginAdvertisingOnNodes(t, nodes)
	f := func(c bitswapTestConfig) bool {
		return c.execute(nodes) == nil
	}
	require.NoError(t, quick.Check(f, nil))
}
