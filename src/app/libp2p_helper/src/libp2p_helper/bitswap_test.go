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
	ipld "github.com/ipfs/go-ipld-format"
	multihash "github.com/multiformats/go-multihash"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/blake2b"
)

type bitswapTestNodeParams struct {
	resource  []byte
	requests1 []int
	requests2 []int
}
type bitswapTestAttempt []bitswapTestNodeParams
type bitswapTestConfig []bitswapTestAttempt

func initBitswapTestConfig(r *rand.Rand, numNodes, numAttempts, numRequests, maxBlobSize int) bitswapTestConfig {
	conf := make([]bitswapTestAttempt, numAttempts)
	for ai := range conf {
		conf[ai] = make(bitswapTestAttempt, numNodes)
		for ni := range conf[ai] {
			n := &conf[ai][ni]
			n.resource = make([]byte, r.Intn(maxBlobSize)+100)
			r.Read(n.resource)
			n.requests1 = make([]int, numRequests)
			n.requests2 = make([]int, numRequests)
			for ri := range n.requests1 {
				n.requests1[ri] = r.Intn(numNodes)
				n.requests2[ri] = r.Intn(numNodes)
			}
		}
	}
	return conf
}

func (bitswapTestConfig) Generate(r *rand.Rand, size int) reflect.Value {
	return reflect.ValueOf(initBitswapTestConfig(r, 20, 10, 3, size))
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

func deleteResource(n testNode, root root) error {
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
	err = ids.At(0).SetBlake2bHash(root[:])
	if err != nil {
		return err
	}
	DeleteResourcePush(m).handle(n.node)
	return nil
}

func awaitRemoval(n testNode, root root) error {
	resUpdErr := func(s string, args ...interface{}) error {
		return fmt.Errorf("Unexpected ResourceUpdate on remove: "+s, args...)
	}
	var m ipc.DaemonInterface_ResourceUpdate
	var received bool
	select {
	case m, received = <-n.trap.ResourceUpdate:
	case <-n.node.bitswapCtx.ctx.Done():
		return nil
	}
	if !received {
		return errors.New("resourceUpdate trap closed")
	}
	if m.Type() != ipc.ResourceUpdateType_removed {
		return resUpdErr("wrong type %d", m.Type())
	}
	var ids ipc.RootBlockId_List
	ids, err := m.Ids()
	if err != nil {
		return err
	}
	var ids_ []BitswapBlockLink
	ids_, err = getRootIds(ids)
	if err != nil {
		return err
	}
	if len(ids_) != 1 || !bytes.Equal(ids_[0][:], root[:]) {
		return resUpdErr("wrong ids")
	}
	return nil
}

func (at bitswapTestAttempt) publish(nodes []testNode) error {
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

func (at bitswapTestAttempt) awaitPublish(nodes []testNode) (resIds []BitswapBlockLink, err error) {
	resIds = make([]BitswapBlockLink, len(nodes))
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
		err := bs.storage.ViewBlock(bs.ctx, h, func(actualB []byte) error {
			return nil
		})
		if err == nil {
			return fmt.Errorf("block %s wasn't deleted", codanet.BlockHashToCidSuffix(h))
		} else if err != (ipld.ErrNotFound{Cid: codanet.BlockHashToCid(h)}) {
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
		err := bs.storage.ViewBlock(bs.ctx, h, func(actualB []byte) error {
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
func (at bitswapTestAttempt) requestResources(nodes []testNode, roots []BitswapBlockLink, getRequests func(*bitswapTestNodeParams) []int) (err error) {
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
func (at bitswapTestAttempt) awaitResourceDownload(nodes []testNode, roots []BitswapBlockLink, getRequests func(*bitswapTestNodeParams) []int) error {
	errChan := make(chan error, len(at))
	setResUpdErr := func(s string, args ...interface{}) {
		errChan <- fmt.Errorf("Unexpected ResourceUpdate on download: "+s, args...)
	}
	ctxs := make([]context.Context, len(at))
	cancels := make([]context.CancelFunc, len(at))
	for ni := range at {
		// ctx, cancelF := context.WithTimeout(nodes[ni].node.Ctx, 5*time.Second)
		ctx, cancelF := context.WithCancel(nodes[ni].node.Ctx)
		ctxs[ni] = ctx
		cancels[ni] = cancelF
		go func(ni int) {
			allIds := make(map[BitswapBlockLink]bool)
			remained := make(map[BitswapBlockLink]bool)
			for _, resId := range getRequests(&at[ni]) {
				nodes[ni].node.P2p.Logger.Infof("node %d downloads resource %d (%s)", ni, resId, codanet.BlockHashToCidSuffix(roots[resId]))
				allIds[roots[resId]] = true
				remained[roots[resId]] = true
			}
			for {
				if len(remained) == 0 {
					break
				}
				var m ipc.DaemonInterface_ResourceUpdate
				var received bool
				select {
				case m, received = <-nodes[ni].trap.ResourceUpdate:
				case <-ctx.Done():
					return
				}
				if !received {
					errChan <- errors.New("ResourceUpdate trap closed")
					return
				}
				if m.Type() != ipc.ResourceUpdateType_added {
					setResUpdErr("unexpected type %d", m.Type())
					return
				}
				ids, err := m.Ids()
				if err != nil {
					errChan <- err
					return
				}
				var ids_ []BitswapBlockLink
				ids_, err = getRootIds(ids)
				if err != nil {
					errChan <- err
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
			cancelF()
		}(ni)
	}
loop:
	for i, ctx := range ctxs {
		var err error
		select {
		case <-ctx.Done():
			if ctx.Err() == context.Canceled {
				continue loop
			} else {
				err = fmt.Errorf("%d: %v", i, ctx.Err())
			}
		case err = <-errChan:
		}
		if err != nil {
			for j := i; j < len(cancels); j++ {
				cancels[j]()
			}
			nodes[i].node.P2p.Logger.Errorf("awaitResourceDownload failed: %v", err)
			return err
		}
	}
	return nil
}
func (at bitswapTestAttempt) confirmResourceDownload(nodes []testNode, getRequests func(*bitswapTestNodeParams) []int) error {
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

func (at *bitswapTestAttempt) downloadAndCheckResources(nodes []testNode, roots []BitswapBlockLink, getRequests func(*bitswapTestNodeParams) []int) (err error) {
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

func (conf bitswapTestConfig) execute(nodes []testNode, delayBeforeDownload bool) error {
	for _, at := range conf {
		err := at.publish(nodes)
		if err != nil {
			return fmt.Errorf("Error publishing: %v", err)
		}
		roots, err := at.awaitPublish(nodes)
		if err != nil {
			return fmt.Errorf("Error awaiting publish: %v", err)
		}
		for ni, nconf := range at {
			bs := nodes[ni].node.bitswapCtx
			err = confirmBlocksInStorage(bs, nconf.resource)
			if err != nil {
				return fmt.Errorf("Error confirming blocks in storage: %v", err)
			}
		}
		if delayBeforeDownload {
			time.Sleep(11 * time.Second)
			trimConnections(nodes)
		}
		err = at.downloadAndCheckResources(nodes, roots, func(p *bitswapTestNodeParams) []int {
			return p.requests1
		})
		if err != nil {
			return fmt.Errorf("Error downloading/checking resources: %v", err)
		}
		resourceReplicated := make(map[int]bool)
		for ni, n := range at {
			for _, r := range n.requests1 {
				if ni == r {
					continue
				}
				resourceReplicated[r] = true
			}
		}
		for ni := range nodes {
			if !resourceReplicated[ni] {
				continue
			}
			err = deleteResource(nodes[ni], roots[ni])
			if err != nil {
				return fmt.Errorf("Error removing own resources: %v", err)
			}
		}
		type el struct {
			err error
			ni  int
		}
		errChan := make(chan el, len(resourceReplicated))
		for ni := range nodes {
			if !resourceReplicated[ni] {
				continue
			}
			go func(ni int) {
				errChan <- el{err: awaitRemoval(nodes[ni], roots[ni]), ni: ni}
			}(ni)
		}
		for i := 0; i < len(resourceReplicated); i++ {
			el := <-errChan
			if el.err != nil {
				// we just return and context will be closed as part of test cleanup
				return fmt.Errorf("Error awaiting own resource removal on %d: %v", el.ni, el.err)
			}
		}
		for ni, nconf := range at {
			if !resourceReplicated[ni] {
				continue
			}
			bs := nodes[ni].node.bitswapCtx
			err = confirmBlocksNotInStorage(bs, nconf.resource)
			if err != nil {
				return fmt.Errorf("Error confirming blocks not in storage: %v", err)
			}
		}
		if delayBeforeDownload {
			time.Sleep(11 * time.Second)
			trimConnections(nodes)
		}
		err = at.downloadAndCheckResources(nodes, roots, func(p *bitswapTestNodeParams) []int {
			return p.requests2
		})
		if err != nil {
			return fmt.Errorf("Error downloading/checking resources (2): %v", err)
		}
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
		blocks, root := SplitDataToBitswapBlocks(1<<8, b)
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

const resourceUpdateOnlyMask = upcallDropAllMask ^ (1 << ResourceUpdateChan)

func testBitswap(t *testing.T, numNodes, numAttempts, numRequests, maxBlobSize int, delayBeforeDownload bool) {
	nodes, cancels := initNodes(t, numNodes, resourceUpdateOnlyMask)
	// uncomment following lines to print a sed expression that will replace
	// peer ids with node indexes in test logs (useful for debug of tests)

	// seds := []string{}
	// for ni, n := range nodes {
	// 	pid := n.node.P2p.Me.String()
	// 	seds = append(seds, fmt.Sprintf("sed 's/%s/node%d/g'", pid, ni))
	// }
	// fmt.Println(strings.Join(seds, " | "))

	for ni := range nodes {
		go func(ni int) {
			nodes[ni].node.bitswapCtx.Loop()
			cancels[ni]()
		}(ni)
	}
	connectRingTopology(t, nodes, true)
	beginAdvertisingOnNodes(t, nodes)
	seed := time.Now().Unix()
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))
	conf := initBitswapTestConfig(r, numNodes, numAttempts, numRequests, maxBlobSize)
	err := conf.execute(nodes, delayBeforeDownload)
	if err != nil {
		printConnectionGraph(buildConnectionGraph(nodes))
	}
	require.NoError(t, err)
}

// Caution: this test requires up to 30GB of RAM and runs for 10-15 min
func TestBitswapJumbo(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping TestBitswapJumbo in short mode")
		return
	}
	testBitswap(t, 500, 1, 1, 1<<16, true)
}

// Runs for 10 min
func TestBitswapMedium(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping TestBitswapMedium in short mode")
		return
	}
	testBitswap(t, 100, 10, 5, 1<<16, true)
}

func TestBitswapSmoke(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping TestBitswapSmoke in short mode")
		return
	}
	testBitswap(t, 50, 1, 1, 1<<16, true)
}

func TestBitswapSmall(t *testing.T) {
	testBitswap(t, 20, 100, 5, 1<<16, false)
}

func TestBitswapQC(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping TestBitswapQC in short mode")
		return
	}
	nodes, cancels := initNodes(t, 20, resourceUpdateOnlyMask)
	for ni := range nodes {
		go func(ni int) {
			nodes[ni].node.bitswapCtx.Loop()
			cancels[ni]()
		}(ni)
	}
	connectRingTopology(t, nodes, true)
	beginAdvertisingOnNodes(t, nodes)
	f := func(c bitswapTestConfig) bool {
		return c.execute(nodes, false) == nil
	}
	require.NoError(t, quick.Check(f, nil))
}
