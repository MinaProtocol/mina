package main

import (
	"bytes"
	"codanet"
	"context"
	"errors"
	"fmt"
	ipc "libp2p_ipc"
	"math/rand"
	"reflect"
	"testing"
	"testing/quick"
	"time"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/ipfs/go-cid"
	blockstore "github.com/ipfs/go-ipfs-blockstore"
	multihash "github.com/multiformats/go-multihash"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/blake2b"
)

const REQS_PER_NODE = 3

// TODO use CONNS_LO = 2
const CONNS_LO = 7
const CONNS_HI = CONNS_LO + REQS_PER_NODE

const NUM_NODES = 10

type bitswapTestNodeParams struct {
	resource  []byte
	requests1 [REQS_PER_NODE]int
	requests2 [REQS_PER_NODE]int
}
type bitswapTestAttempt [NUM_NODES]bitswapTestNodeParams
type bitswapTestConfig []bitswapTestAttempt
type bitswapTestNode struct {
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

func removeOwn(nodes [NUM_NODES]bitswapTestNode, nodeRoots [NUM_NODES]BitswapBlockLink) error {
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

func awaitRemoval(nodes [NUM_NODES]bitswapTestNode, nodeRoots [NUM_NODES]BitswapBlockLink) (err error) {
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

func (at *bitswapTestAttempt) publish(nodes [NUM_NODES]bitswapTestNode) error {
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

func (at *bitswapTestAttempt) awaitPublish(nodes [NUM_NODES]bitswapTestNode) (resIds [NUM_NODES]BitswapBlockLink, err error) {
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
func (at *bitswapTestAttempt) requestResources(nodes [NUM_NODES]bitswapTestNode, roots [NUM_NODES]BitswapBlockLink, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) (err error) {
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
func (at *bitswapTestAttempt) awaitResourceDownload(nodes [NUM_NODES]bitswapTestNode, roots [NUM_NODES]BitswapBlockLink, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) (err error) {
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
func (at *bitswapTestAttempt) confirmResourceDownload(nodes [NUM_NODES]bitswapTestNode, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) error {
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

func (at *bitswapTestAttempt) downloadAndCheckResources(nodes [NUM_NODES]bitswapTestNode, roots [NUM_NODES]BitswapBlockLink, getRequests func(*bitswapTestNodeParams) [REQS_PER_NODE]int) (err error) {
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
func (conf bitswapTestConfig) execute(nodes [NUM_NODES]bitswapTestNode) error {
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

func testBitswapInitNodes(t *testing.T) (nodes [NUM_NODES]bitswapTestNode) {
	firstNode := newTestAppWithMaxConns(t, nil, false, CONNS_LO, CONNS_HI, nextPort())
	firstNode.NoDHT = true
	// beginAdvertisingSendAndCheck(t, firstNode)

	infos, err := addrInfos(firstNode.P2p.Host)
	require.NoError(t, err)

	errChans := []chan error{}

	// Launch a process to monitor number of open connections

	done := make(chan interface{})
	var cancels [NUM_NODES]context.CancelFunc

	for ni := 0; ni < NUM_NODES; ni++ {
		trap := newUpcallTrap(fmt.Sprintf("node %d", ni), 64, upcallDropAllMask^(1<<ResourceUpdateChan))
		ctx, cancelF := context.WithCancel(context.Background())
		cancels[ni] = cancelF
		node := newTestAppWithMaxConnsAndCtx(t, infos, false, CONNS_LO, CONNS_HI, nextPort(), ctx)
		errChan := launchFeedUpcallTrap(t, node.OutChan, trap, done)
		errChans = append(errChans, errChan)
		infos, err = addrInfos(node.P2p.Host)
		// to ensure connectivity is not lost
		// node.P2p.ConnectionManager.Protect(infos[0].ID, "seed")
		require.NoError(t, err)
		nodes[ni].node = node
		nodes[ni].trap = trap
		node.NoDHT = true
		beginAdvertisingSendAndCheck(t, node)
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

func TestBitswap(t *testing.T) {
	nodes := testBitswapInitNodes(t)
	conf := initBitswapTestConfig(rand.New(rand.NewSource(1)), 10, 1<<23)
	require.NoError(t, conf.execute(nodes))
}
func TestBitswapQC(t *testing.T) {
	nodes := testBitswapInitNodes(t)
	f := func(c bitswapTestConfig) bool {
		return c.execute(nodes) == nil
	}
	require.NoError(t, quick.Check(f, nil))
}
