package main

import (
	"codanet"
	"container/heap"
	"context"
	"encoding/binary"
	"fmt"
	"io/ioutil"
	ipc "libp2p_ipc"
	"math"
	"math/rand"
	"testing"
	"time"

	blocks "github.com/ipfs/go-block-format"
	"github.com/ipfs/go-cid"
	ipld "github.com/ipfs/go-ipld-format"
	"github.com/stretchr/testify/require"
)

type blockGroupStart struct {
	root root
	tag  BitswapDataTag
}

type blockGroup struct {
	blocks       map[cid.Cid][]byte
	starts       []blockGroupStart
	maxBlockSize int
}

func (b blockGroup) print() {
	fmt.Printf("max block size: %d\n", b.maxBlockSize)
	notVisited := make(map[cid.Cid]bool)
	for b := range b.blocks {
		notVisited[b] = true
	}
	q := make([]BitswapBlockLink, 0, len(b.blocks))
	for _, start := range b.starts {
		q = append(q, start.root)
	}
	suffix := func(id cid.Cid) string {
		s := id.String()
		return s[len(s)-6:]
	}
	noBody := make([]cid.Cid, 0)
	brokenBody := make([]cid.Cid, 0)
	file, err := ioutil.TempFile("", "bg*.dot")
	if err != nil {
		fmt.Println("Failed to create a tmp dot file")
		return
	}
	fmt.Printf("Writing to %s\n", file.Name())
	defer file.Close()
	file.WriteString(fmt.Sprintln("digraph bg{"))
	for ; len(q) > 0; q = q[1:] {
		node := q[0]
		id := codanet.BlockHashToCid(node)
		if !notVisited[id] {
			continue
		}
		delete(notVisited, id)
		b, hasB := b.blocks[id]
		if hasB {
			links, _, err := ReadBitswapBlock(b)
			if err != nil {
				brokenBody = append(brokenBody, id)
			}
			for _, l := range links {
				file.WriteString(fmt.Sprintf("\tn_%s -> n_%s;\n", suffix(id), codanet.BlockHashToCidSuffix(l)))
				q = append(q, l)
			}
		} else {
			noBody = append(noBody, id)
		}
	}
	file.WriteString(fmt.Sprintln("}"))
	fmt.Printf("orphans:")
	for id := range notVisited {
		fmt.Printf(" %s", suffix(id))
	}
	fmt.Println()
	fmt.Printf("no body:")
	for _, id := range noBody {
		fmt.Printf(" %s", suffix(id))
	}
	fmt.Println()
	fmt.Printf("broken body:")
	for _, id := range brokenBody {
		fmt.Printf(" %s", suffix(id))
	}
	fmt.Println()
}

func genMaxBlockSize(r *rand.Rand, max int) int {
	maxBlockSize := r.Intn(max-40) + 40
	diff := (maxBlockSize - 2) % BITSWAP_BLOCK_LINK_SIZE
	if diff < 5 {
		maxBlockSize = maxBlockSize + 5 - diff
	}
	return maxBlockSize
}

func genValidBlockGroup(r *rand.Rand, tag BitswapDataTag) blockGroup {
	dataLen := r.Intn(100000) + 64
	return genValidBlockGroupImpl(r, genMaxBlockSize(r, 1000), dataLen, tag)
}
func genValidBlockGroupImpl(r *rand.Rand, maxBlockSize, dataLen int, tag BitswapDataTag) blockGroup {
	data := make([]byte, dataLen+1)
	data[0] = byte(tag)
	r.Read(data[1:])
	blocksRaw, root_ := SplitDataToBitswapBlocksLengthPrefixedWithHashF(maxBlockSize, badHash, data)
	blocks := make(map[cid.Cid][]byte)
	for bLink, b := range blocksRaw {
		blocks[codanet.BlockHashToCid(bLink)] = b
	}
	return blockGroup{
		starts:       []blockGroupStart{{root: root_, tag: tag}},
		blocks:       blocks,
		maxBlockSize: maxBlockSize,
	}
}

func (bg *blockGroup) addDuplicateOfRoot(r *rand.Rand, rootIx int, tag BitswapDataTag) int {
	n := len(bg.blocks)
	subRoot := bg.starts[rootIx].root
	var subDataLen int
	{
		_, rootBlockData, err := ReadBitswapBlock(bg.blocks[codanet.BlockHashToCid(subRoot)])
		panicOnErr(err)
		_, subDataLen, err = ExtractLengthFromRootBlockData(rootBlockData)
		panicOnErr(err)
	}
	lpb := LinksPerBlock(bg.maxBlockSize)
	fullN := 1
	for pw := lpb; fullN < n; pw = pw * lpb {
		fullN = fullN + pw
	}
	sisterDataLen := fullN*(bg.maxBlockSize-2) - (fullN-1)*BITSWAP_BLOCK_LINK_SIZE
	var sisterRoot root
	var sisterBlocks map[BitswapBlockLink][]byte
	if sisterDataLen == subDataLen+4 || lpb == 1 {
		sisterBlocks = make(map[[32]byte][]byte)
		sisterRoot = subRoot
	} else {
		sisterData := make([]byte, sisterDataLen)
		r.Read(sisterData)
		sisterBlocks, sisterRoot = SplitDataToBitswapBlocks(bg.maxBlockSize, sisterData)
	}
	totDataLen := sisterDataLen*(lpb-1) + subDataLen + 4 + (bg.maxBlockSize-2)%BITSWAP_BLOCK_LINK_SIZE - 4
	rootBlock := make([]byte, bg.maxBlockSize)
	binary.LittleEndian.PutUint16(rootBlock, uint16(lpb))
	for i := 0; i < lpb-1; i++ {
		copy(rootBlock[2+i*BITSWAP_BLOCK_LINK_SIZE:], sisterRoot[:])
	}
	copy(rootBlock[2+(lpb-1)*BITSWAP_BLOCK_LINK_SIZE:], subRoot[:])
	binary.LittleEndian.PutUint32(rootBlock[2+lpb*BITSWAP_BLOCK_LINK_SIZE:], uint32(totDataLen))
	rootBlock[2+lpb*BITSWAP_BLOCK_LINK_SIZE+4] = byte(tag)
	r.Read(rootBlock[2+lpb*BITSWAP_BLOCK_LINK_SIZE+5:])
	for sbLink, sb := range sisterBlocks {
		bg.blocks[codanet.BlockHashToCid(sbLink)] = sb
	}
	newRoot := badHash(rootBlock)
	bg.blocks[codanet.BlockHashToCid(newRoot)] = rootBlock
	bg.starts = append(bg.starts, blockGroupStart{root: newRoot, tag: tag})
	return len(bg.starts) - 1
}

func genValidBlockGroupWithManyDuplicates(r *rand.Rand, tag1 BitswapDataTag, tag2 BitswapDataTag, tag3 BitswapDataTag) blockGroup {
	maxBlockSize := genMaxBlockSize(r, 256)
	lpb := LinksPerBlock(maxBlockSize)
	// 3 full layers
	fullN := 1 + lpb + lpb*lpb
	dataLen := fullN*(maxBlockSize-2) - (fullN-1)*BITSWAP_BLOCK_LINK_SIZE - 5
	bg := genValidBlockGroupImpl(r, maxBlockSize, dataLen, tag1)
	bg.addDuplicateOfRoot(r, bg.addDuplicateOfRoot(r, 0, tag2), tag3)
	return bg
}

type linkHeapItem struct {
	link BitswapBlockLink
	prio int
}
type linkHeap []linkHeapItem

func (h linkHeap) Len() int { return len(h) }
func (h linkHeap) Less(i, j int) bool {
	return h[i].prio > h[j].prio
}

func (pq linkHeap) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
}

func (pq *linkHeap) Push(x interface{}) {
	*pq = append(*pq, x.(linkHeapItem))
}

func (h *linkHeap) PopLink() (l BitswapBlockLink, has bool) {
	if h.Len() > 0 {
		l = heap.Pop(h).(linkHeapItem).link
		has = true
	}
	return
}
func (pq *linkHeap) Pop() interface{} {
	old := *pq
	n := len(old)
	item := old[n-1]
	*pq = old[0 : n-1]
	return item
}

type testRootParams struct {
	tag    BitswapDataTag
	schema *BitswapBlockSchema
}

func (rp *testRootParams) setSchema(s *BitswapBlockSchema) {
	if rp.schema != nil {
		panic("double call on setSchema")
	}
	rp.schema = s
}

func (rp *testRootParams) getSchema() *BitswapBlockSchema {
	return rp.schema
}

func (rp *testRootParams) getTag() BitswapDataTag {
	return rp.tag
}

func (bg *blockGroup) execute(r *rand.Rand, tagConfig map[BitswapDataTag]BitswapDataConfig) malformedRoots {
	visited := make(map[BitswapBlockLink]bool)
	q := make(linkHeap, 0)
	heap.Init(&q)
	nodeParams := make(map[BitswapBlockLink]map[root][]NodeIndex)
	rootParams := make(map[root]RootParams)
	pushHeap := func(s BitswapBlockLink) {
		if !visited[s] {
			visited[s] = true
			heap.Push(&q, linkHeapItem{
				link: s,
				prio: r.Int(),
			})
		}
	}
	for _, s := range bg.starts {
		pushHeap(s.root)
		rootParams[s.root] = &testRootParams{tag: s.tag}
		nodeParams[s.root] = map[root][]NodeIndex{s.root: {0}}
	}
	di := MkDepthIndices(LinksPerBlock(bg.maxBlockSize), 100000)
	malformed := make(malformedRoots)
	for link, hasLink := q.PopLink(); hasLink; link, hasLink = q.PopLink() {
		visited[link] = false
		linkCid := codanet.BlockHashToCid(link)
		blockData := bg.blocks[linkCid]
		block, _ := blocks.NewBlockWithCid(blockData, linkCid)
		np, hasNP := nodeParams[link]
		if !hasNP {
			panic("unexpected no np")
		}
		delete(nodeParams, link)
		children, malformed_ := processDownloadedBlockStep(np, block, rootParams, bg.maxBlockSize, di, tagConfig)
		for child, childMap := range children {
			np, hasNp := nodeParams[child]
			if !hasNp {
				np = make(map[root][]NodeIndex)
				nodeParams[child] = np
			}
			for root, ixs := range childMap {
				np[root] = append(np[root], ixs...)
			}
			pushHeap(child)
		}
		for root, err := range malformed_ {
			malformed[root] = err
		}
	}
	return malformed
}

func genInvalidBlockGroupNoTagInRoot(r *rand.Rand) blockGroup {
	maxBlockSize := genMaxBlockSize(r, 1000)
	maxBlockSize = maxBlockSize - (maxBlockSize-2)%BITSWAP_BLOCK_LINK_SIZE + 4
	dataLen := LinksPerBlock(maxBlockSize) * maxBlockSize
	return genValidBlockGroupImpl(r, maxBlockSize, dataLen, 0)
}

func genInvalidBlockGroupDataTooLarge(r *rand.Rand) (blockGroup, int) {
	dataLen := r.Intn(100000) + 64
	bg := genValidBlockGroupImpl(r, genMaxBlockSize(r, 1000), dataLen, 0)
	return bg, dataLen
}

type bitswapTreeProto struct {
	maxBlockSize      uint8
	lastLinkNodeIx    uint8 // index of last node with any links
	lastLinkNodeCount uint8 // count of links in the last node with links

	// maxLinkMask is a bitmask array for booleans that determine whether
	// the given block is expected to have maximum link count;
	// only indexes from `0` to `lastLinkNodeIx - 1` are considered
	maxLinkMask [4]uint64

	// maxSizeMask is a bitmask array for booleans that determine whether
	// the given block is expected to have maximum size;
	// only indexes from `0` to `total - 1` are considered, where total
	// is the total amount of blocks in the tree
	maxSizeMask [32]uint64
}

func genProto(r *rand.Rand) (proto bitswapTreeProto) {
	return genProtoWithMaxBlockSize(r, genMaxBlockSize(r, math.MaxUint8))
}
func genProtoWithMaxBlockSize(r *rand.Rand, maxBlockSize int) (proto bitswapTreeProto) {
	lpb := LinksPerBlock(maxBlockSize)
	lastLinkNodeIx := r.Intn(math.MaxUint8)
	lastLinkNodeCount := 1
	if lpb > 1 {
		lastLinkNodeCount += r.Intn(lpb - 1)
	}
	if lastLinkNodeCount > lpb {
		panic("unexpected blabla")
	}
	proto.maxBlockSize = uint8(maxBlockSize)
	proto.lastLinkNodeCount = uint8(lastLinkNodeCount)
	proto.lastLinkNodeIx = uint8(lastLinkNodeIx)
	total := lastLinkNodeCount + 1
	if lastLinkNodeIx > 0 {
		total += lpb * lastLinkNodeIx
	}
	li := (lastLinkNodeIx - 1) / 64
	var v uint64 = math.MaxUint64
	for i := 0; i <= li; i++ {
		if lpb > 1 {
			v = r.Uint64()
		}
		proto.maxLinkMask[i] = v
	}
	si := (total - 2) / 64
	for i := 0; i <= si; i++ {
		proto.maxSizeMask[i] = r.Uint64()
	}
	rootMaxLinkRem := maxBlockSize - lpb*BITSWAP_BLOCK_LINK_SIZE - 2 - 5
	if rootMaxLinkRem == 0 {
		proto.maxSizeMask[0] = proto.maxSizeMask[0] | 1
	}
	return
}

var CUM64_MASKS [64]uint64

func init() {
	CUM64_MASKS[0] = 1
	for i := 1; i < 64; i++ {
		CUM64_MASKS[i] = (1 << i) + CUM64_MASKS[i-1]
	}
}

func (proto *bitswapTreeProto) isValid() bool {
	lpb := LinksPerBlock(int(proto.maxBlockSize))
	lnc := int(proto.lastLinkNodeCount)
	if lnc > lpb {
		panic("broken tree prototype")
	}
	lnix := int(proto.lastLinkNodeIx)
	total := lnc + 1 + lpb*lnix
	if total < 2 {
		return true
	}
	// lnix - 1 is index of last max-link node
	if lnix > 0 {
		li := (lnix - 1) / 64
		lj := (lnix - 1) % 64
		for i := 0; i < li; i++ {
			if proto.maxLinkMask[i] != math.MaxUint64 {
				return false
			}
		}
		if proto.maxLinkMask[li]&CUM64_MASKS[lj] != CUM64_MASKS[lj] {
			return false
		}
	}
	// total - 2 is index of pre-last node
	si := (total - 2) / 64
	sj := (total - 2) % 64
	for i := 0; i < si; i++ {
		if proto.maxSizeMask[i] != math.MaxUint64 {
			return false
		}
	}
	return proto.maxSizeMask[si]&CUM64_MASKS[sj] == CUM64_MASKS[sj]
}

func (proto *bitswapTreeProto) isMaxSizeNode(ix int) bool {
	return proto.maxSizeMask[ix/64]&(1<<(ix%64)) > 0
}
func (proto *bitswapTreeProto) isMaxLinkNode(ix int) bool {
	return proto.maxLinkMask[ix/64]&(1<<(ix%64)) > 0
}
func (proto *bitswapTreeProto) genTreeFromProto(r *rand.Rand, tag BitswapDataTag, sameByte bool) blockGroup {
	var fillData func([]byte)
	if sameByte {
		rbyte := byte(r.Intn(256))
		fillData = func(b []byte) {
			for i := range b {
				b[i] = rbyte
			}
		}
	} else {
		fillData = func(b []byte) {
			r.Read(b)
		}
	}
	blocks := make(map[cid.Cid][]byte)
	lpb := LinksPerBlock(int(proto.maxBlockSize))
	lastLIx := int(proto.lastLinkNodeIx)
	ln := make([]int, lastLIx+1)
	ln[lastLIx] = int(proto.lastLinkNodeCount)
	n := 1 + ln[lastLIx]
	for i := 0; i < lastLIx; i++ {
		l := lpb
		if !proto.isMaxLinkNode(i) && lpb > 1 {
			l = 1 + r.Intn(lpb-1)
		}
		ln[i] = l
		n += l
	}
	totSz := 0
	q := make([][]byte, 0, n)
	for i := n - 1; i > lastLIx; i-- {
		sz := int(proto.maxBlockSize) - 2
		if !proto.isMaxSizeNode(i) {
			if i == n-1 {
				sz = 33 + r.Intn(sz-33)
			} else {
				sz = 1 + r.Intn(sz-1)
			}
		}
		totSz += sz
		b := make([]byte, sz+2)
		fillData(b[2:])
		q = append(q, b)
	}
	for i := lastLIx; i >= 0; i-- {
		l := ln[i]
		sz := int(proto.maxBlockSize) - 2
		if !proto.isMaxSizeNode(i) {
			lsz := BITSWAP_BLOCK_LINK_SIZE * l
			if i == 0 {
				lsz += 5
			}
			if sz > lsz {
				sz = lsz + r.Intn(sz-lsz)
			}
		}
		totSz += sz - l*BITSWAP_BLOCK_LINK_SIZE
		b := make([]byte, sz+2)
		binary.LittleEndian.PutUint16(b, uint16(l))
		ls := q[:l]
		for i, block := range ls {
			link := badHash(block)
			blocks[codanet.BlockHashToCid(link)] = block
			copy(b[2+BITSWAP_BLOCK_LINK_SIZE*(l-i-1):], link[:])
		}
		if i == 0 {
			fillData(b[2+BITSWAP_BLOCK_LINK_SIZE*l+5:])
			rootPrefixL := l*BITSWAP_BLOCK_LINK_SIZE + 2
			binary.LittleEndian.PutUint32(b[rootPrefixL:], uint32(totSz-4))
			b[rootPrefixL+4] = byte(tag)
		} else {
			fillData(b[2+BITSWAP_BLOCK_LINK_SIZE*l:])
		}
		q = append(q[l:], b)
	}
	if len(q) != 1 {
		panic("genTreeFromProto: len(q) != 1")
	}
	rootBlock := q[0]
	root := badHash(rootBlock)
	blocks[codanet.BlockHashToCid(root)] = rootBlock
	return blockGroup{
		maxBlockSize: int(proto.maxBlockSize),
		starts:       []blockGroupStart{{root: root, tag: tag}},
		blocks:       blocks,
	}
}

func TestProcessDownloadedBlockStepInvalidStructure(t *testing.T) {
	tagConfig := map[BitswapDataTag]BitswapDataConfig{
		0: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
	}
	seed := time.Now().Unix()
	// 1635580518
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))

	proto1 := bitswapTreeProto{maxBlockSize: 94, lastLinkNodeIx: 0, lastLinkNodeCount: 1}
	proto1.maxLinkMask[0] = 1071357051012973767
	proto1.maxSizeMask[0] = 4186564977694381551
	require.True(t, proto1.isValid())
	for j := 0; j < 1000; j++ {
		tree := proto1.genTreeFromProto(r, 0, j&1 == 0)
		require.Equal(t, 0, len(tree.execute(r, tagConfig)))
	}

	proto2 := bitswapTreeProto{maxBlockSize: 94, lastLinkNodeIx: 0, lastLinkNodeCount: 1}
	proto2.maxLinkMask[0] = 6488583331436132323
	proto2.maxSizeMask[0] = 10458209133121214137
	require.True(t, proto2.isValid())
	for j := 0; j < 1000; j++ {
		tree := proto2.genTreeFromProto(r, 0, j&1 == 0)
		require.Equal(t, 0, len(tree.execute(r, tagConfig)))
	}

	for i := 0; i < 10000; i++ {
		proto := genProto(r)
		// with overwhelming probability generated proto is invalid, but we check here just in case
		isValid := proto.isValid()
		for j := 0; j < 100; j++ {
			tree := proto.genTreeFromProto(r, 0, j&1 == 0)
			m := tree.execute(r, tagConfig)
			if (len(m) == 0) != isValid {
				t.Logf("%v", proto)
				t.FailNow()
			}
		}
	}
}

func TestProcessDownloadedBlockStep(t *testing.T) {
	tagConfig := map[BitswapDataTag]BitswapDataConfig{
		0: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
		1: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
		2: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
	}
	seed := time.Now().Unix()
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))
	for i := 0; i < 1000; i++ {
		// Basic test
		bg1 := genValidBlockGroup(r, 0)
		require.Equal(t, 0, len(bg1.execute(r, tagConfig)))
		// Unknown tag
		root1 := bg1.starts[0].root
		root1Cid := codanet.BlockHashToCid(root1)
		m1 := bg1.execute(r, map[BitswapDataTag]BitswapDataConfig{})
		_, m1HasRoot := m1[root1]
		require.True(t, m1HasRoot && len(m1) >= 1)
		// Duplicate tree as subtree of a new block tree
		bg1.addDuplicateOfRoot(r, 0, 1)
		require.Equal(t, 0, len(bg1.execute(r, tagConfig)))
		// Replace one block with invalid block and back again
		// we do not recalculate links as they are not recalculated
		// during processing
		var link1Cid cid.Cid
		var block1 []byte
		for link1Cid, block1 = range bg1.blocks {
			if !link1Cid.Equals(root1Cid) {
				break
			}
		}
		b1 := make([]byte, len(block1))
		copy(b1, block1)
		b1[0] = 0xff
		b1[1] = 0xff
		blocks1 := [][]byte{
			{0},
			{},
			b1,
		}
		for _, b := range blocks1 {
			bg1.blocks[link1Cid] = b
			require.Less(t, 0, len(bg1.execute(r, tagConfig)))
		}
		bg1.blocks[link1Cid] = block1
		root1Block := bg1.blocks[root1Cid]
		bg1.blocks[root1Cid] = root1Block[:5]
		require.Less(t, 0, len(bg1.execute(r, tagConfig)))
		bg1.blocks[root1Cid] = root1Block
		// Duplicate three subtrees
		bg3 := genValidBlockGroupWithManyDuplicates(r, 0, 1, 0)
		require.Equal(t, 0, len(bg3.execute(r, tagConfig)))
		// No tag in root
		bg4 := genInvalidBlockGroupNoTagInRoot(r)
		require.False(t, IsValidMaxBlockSize(bg4.maxBlockSize))
		m4 := bg4.execute(r, tagConfig)
		_, m4HasRoot := m4[bg4.starts[0].root]
		require.True(t, m4HasRoot && len(m4) >= 1)
		// Data too large
		bg5, dataLen := genInvalidBlockGroupDataTooLarge(r)
		for j := -2; j <= 2; j++ {
			m5 := bg5.execute(r, map[BitswapDataTag]BitswapDataConfig{
				0: {maxSize: dataLen + j, downloadTimeout: time.Minute},
			})
			_, m5HasRoot := m5[bg5.starts[0].root]
			if j >= 0 {
				require.Equal(t, 0, len(m5))
			} else {
				require.True(t, m5HasRoot && len(m5) >= 1)
			}
		}
	}
}

type testBitswapState struct {
	r                  *rand.Rand
	statuses           map[BitswapBlockLink]codanet.RootBlockStatus
	blocks             map[cid.Cid][]byte
	nodeDownloadParams map[cid.Cid]map[root][]NodeIndex
	rootDownloadStates map[root]*RootDownloadState
	// awaiting blocks queue: mapping from random index to next key to evict
	awaitingBlocksQ    map[uint64]cid.Cid
	awaitingBlocks     map[cid.Cid]interface{}
	blockSink          chan<- blocks.Block
	maxBlockSize       int
	depthIndices       *DepthIndices
	resourceUpdates    map[root]ipc.ResourceUpdateType
	checkInvariantsNow func() bool
	deadlines          []struct {
		root            root
		downloadTimeout time.Duration
	}
}

func (bs *testBitswapState) NodeDownloadParams() map[cid.Cid]map[root][]NodeIndex {
	return bs.nodeDownloadParams
}
func (bs *testBitswapState) RootDownloadStates() map[root]*RootDownloadState {
	return bs.rootDownloadStates
}
func (bs *testBitswapState) MaxBlockSize() int {
	return bs.maxBlockSize
}

func (bs *testBitswapState) DepthIndices() DepthIndices {
	if bs.depthIndices == nil {
		di := MkDepthIndices(LinksPerBlock(bs.maxBlockSize), 100000)
		bs.depthIndices = &di
	}
	return *bs.depthIndices
}

func (bs *testBitswapState) RequestBlocks(keys []cid.Cid) error {
	for _, key := range keys {
		if _, has := bs.awaitingBlocks[key]; has {
			continue
		}
		for {
			v := bs.r.Uint64()
			if _, has := bs.awaitingBlocksQ[v]; !has {
				bs.awaitingBlocksQ[v] = key
				bs.awaitingBlocks[key] = nil
				break
			}
		}
	}
	return nil
}
func (bs *testBitswapState) NewSession(_ time.Duration) (BlockRequester, context.CancelFunc) {
	return bs, func() {}
}
func (bs *testBitswapState) RegisterDeadlineTracker(root_ root, downloadTimeout time.Duration) {
	bs.deadlines = append(bs.deadlines, struct {
		root            root
		downloadTimeout time.Duration
	}{root: root_, downloadTimeout: downloadTimeout})
}
func (bs *testBitswapState) SendResourceUpdate(type_ ipc.ResourceUpdateType, root root) {
	type1, has := bs.resourceUpdates[root]
	if has && type1 != type_ {
		panic("duplicate resource update")
	}
	bs.resourceUpdates[root] = type_
}
func (bs *testBitswapState) GetStatus(key [32]byte) (codanet.RootBlockStatus, error) {
	return bs.statuses[BitswapBlockLink(key)], nil
}
func (bs *testBitswapState) SetStatus(key [32]byte, value codanet.RootBlockStatus) error {
	bs.statuses[BitswapBlockLink(key)] = value
	return nil
}
func (bs *testBitswapState) DeleteStatus(key [32]byte) error {
	delete(bs.statuses, BitswapBlockLink(key))
	return nil
}
func (bs *testBitswapState) DeleteBlocks(keys [][32]byte) error {
	for _, key := range keys {
		delete(bs.blocks, codanet.BlockHashToCid(key))
	}
	return nil
}
func (bs *testBitswapState) ViewBlock(key [32]byte, callback func([]byte) error) error {
	cid := codanet.BlockHashToCid(key)
	b, has := bs.blocks[cid]
	if !has {
		return ipld.ErrNotFound{Cid: cid}
	}
	return callback(b)
}
func (bs *testBitswapState) StoreDownloadedBlock(block blocks.Block) error {
	bs.blocks[block.Cid()] = block.RawData()
	return nil
}

func (bg1 *blockGroup) add(bg blockGroup) {
	if bg1.maxBlockSize != bg.maxBlockSize {
		panic("different block sizes")
	}
	for k, b := range bg.blocks {
		bg1.blocks[k] = b
	}
	bg1.starts = append(bg1.starts, bg.starts...)
}

func (bs *testBitswapState) Context() context.Context {
	return context.Background()
}
func (bs *testBitswapState) CheckInvariants() {
	if !bs.checkInvariantsNow() {
		return
	}
	// TODO consider testing other invariants of internal state
	for _, n := range bs.nodeDownloadParams {
		for r := range n {
			if _, has := bs.rootDownloadStates[r]; !has {
				panic(fmt.Sprintf("missing root state for %s", codanet.BlockHashToCidSuffix(r)))
			}
		}
	}
}

func testBitswapDownloadDo(t *testing.T, r *rand.Rand, bg blockGroup, prepopulatedBlocks *cid.Set, removedBlocks map[cid.Cid]root, expectedToFail []root) {
	expectedToTimeout := map[root]bool{}
	for _, b := range removedBlocks {
		expectedToTimeout[b] = true
	}
	initBlocks := map[cid.Cid][]byte{}
	prepopulatedBlocks.ForEach(func(c cid.Cid) error {
		initBlocks[c] = bg.blocks[c]
		return nil
	})
	totalBlocks := len(bg.blocks)
	blockSink := make(chan blocks.Block, 1000)
	bs := &testBitswapState{
		r:                  r,
		statuses:           map[BitswapBlockLink]codanet.RootBlockStatus{},
		blocks:             initBlocks,
		nodeDownloadParams: map[cid.Cid]map[root][]NodeIndex{},
		rootDownloadStates: map[root]*RootDownloadState{},
		awaitingBlocks:     map[cid.Cid]interface{}{},
		awaitingBlocksQ:    map[uint64]cid.Cid{},
		blockSink:          blockSink,
		maxBlockSize:       bg.maxBlockSize,
		resourceUpdates:    map[root]ipc.ResourceUpdateType{},
		checkInvariantsNow: func() bool {
			return r.Intn(totalBlocks) < 100 // 100 times checking invariants
		},
	}
	expectedToSucceed := map[root]bool{}
	for _, start := range bg.starts {
		expectedToSucceed[start.root] = true
		kickStartRootDownload(start.root, start.tag, bs)
	}
	processBlock := func(block blocks.Block) {
		// Update block storage with the block
		// it's normally done by bitswap, but in tests we have to do it manually
		// after receiving the block
		bs.blocks[block.Cid()] = block.RawData()
		// s := block.Cid().String()
		// t.Logf("Processing block %s", s[len(s)-6:])
		processDownloadedBlock(block, bs)
	}
	processAwaitingBlock := func() {
		var k uint64
		var id cid.Cid
		for k, id = range bs.awaitingBlocksQ {
			break
		}
		delete(bs.awaitingBlocksQ, k)
		delete(bs.awaitingBlocks, id)
		if blockBytes, hasBlock := bg.blocks[id]; hasBlock {
			b, _ := blocks.NewBlockWithCid(blockBytes, id)
			select {
			case bs.blockSink <- b:
			default:
				panic("can not write to block sink")
			}
		} else {
			if _, expected := removedBlocks[id]; !expected {
				t.Errorf("Unexpected block not found: %s", id)
			}
		}
	}
	t.Logf("starting download: %d", len(bs.awaitingBlocks))
loop:
	// Looping invariant: either blockSink or awaitingBlocks are non-empty
	// as soon as both are empty, loop exits
	for i := 0; ; i++ {
		select {
		case block := <-blockSink:
			processBlock(block)
		default:
			if len(bs.awaitingBlocks) == 0 {
				break loop
			}
			processAwaitingBlock()
		}
	}
	expectedToTimeoutTotal := len(expectedToTimeout)
	for _, root := range expectedToFail {
		delete(expectedToSucceed, root)
		if type_, has := bs.resourceUpdates[root]; !has || type_ != ipc.ResourceUpdateType_broken {
			t.Errorf("Expected root %s to emit broken resource update (has=%v, type=%d)",
				codanet.BlockHashToCidSuffix(root), has, type_)
		}
		if _, has := bs.rootDownloadStates[root]; has {
			t.Errorf("Unexpected broken root %s in root download states", codanet.BlockHashToCidSuffix(root))
		}
	}
	for root := range expectedToTimeout {
		delete(expectedToSucceed, root)
		if _, has := bs.resourceUpdates[root]; has {
			t.Errorf("Unexpected resource update for root %s", codanet.BlockHashToCidSuffix(root))
		}
		if _, has := bs.rootDownloadStates[root]; !has {
			t.Errorf("Expected root %s to be in root download states", codanet.BlockHashToCidSuffix(root))
		}
	}
	for root := range expectedToSucceed {
		if type_, has := bs.resourceUpdates[root]; !has || type_ != ipc.ResourceUpdateType_added {
			t.Errorf("Expected root %s to emit added resource update (has=%v, type=%d)",
				codanet.BlockHashToCidSuffix(root), has, type_)
		}
		if _, has := bs.rootDownloadStates[root]; has {
			t.Errorf("Unexpected added root %s in root download states", codanet.BlockHashToCidSuffix(root))
		}
	}
	for _, pair := range bs.deadlines {
		root := pair.root
		if _, has := bs.rootDownloadStates[root]; !has || pair.downloadTimeout > TEST_DOWNLOAD_TIMEOUT {
			continue
		}
		if expectedToTimeout[root] {
			delete(expectedToTimeout, root)
		} else {
			t.Errorf("Unexpected root %s in deadlineChan", codanet.BlockHashToCidSuffix(root))
		}
	}
	if len(expectedToTimeout) != 0 {
		t.Error("Expected more items on deadline chan")
	}
	if expectedToTimeoutTotal != len(bs.rootDownloadStates) {
		t.Error("Unexpected number of root download states")
	}
}

func genLargeBlockGroup(r *rand.Rand) (blockGroup, map[cid.Cid]root, []root) {
	removedBlocks := make(map[cid.Cid]root)
	expectFail := make([]root, 0)
	bg1 := genValidBlockGroupImpl(r, genMaxBlockSize(r, 1000), r.Intn(100000)+64, 0)
	_ = bg1.addDuplicateOfRoot(r, 0, 0)
	for j := 0; j < 20; j++ {
		bg1.add(genValidBlockGroupImpl(r, bg1.maxBlockSize, 256+r.Intn(10000), 0))
	}
	invalidProtos := 5
	if bg1.maxBlockSize > math.MaxUint8 {
		invalidProtos = 0
	}
	// Generate blocks with invalid structure
	for j := 0; j < invalidProtos; j++ {
		proto := genProtoWithMaxBlockSize(r, bg1.maxBlockSize)
		// with overwhelming probability generated proto is invalid, but we check here just in case
		isValid := proto.isValid()
		for k := 0; k < 10; k++ {
			bg := proto.genTreeFromProto(r, 0, k&1 == 0)
			if !isValid {
				for _, s := range bg.starts {
					expectFail = append(expectFail, s.root)
				}
			}
			bg1.add(bg)
		}
	}
	// Generate blocks which exceed max blob size of their tag
	for j := 0; j < 5; j++ {
		bg := genValidBlockGroupImpl(r, bg1.maxBlockSize, TEST_MAX_SIZE_3*2, 2)
		for _, s := range bg.starts {
			expectFail = append(expectFail, s.root)
		}
		bg1.add(bg)
	}
	// Hold out some of the blocks of some roots that are expected to timeout
	for j := 0; j < 5; j++ {
		bg := genValidBlockGroupImpl(r, bg1.maxBlockSize, 256+r.Intn(10000), 1)
		if len(bg.starts) != 1 {
			panic("unexpected many starts")
		}
		var firstKey cid.Cid
		for firstKey = range bg.blocks {
			break
		}
		removedBlocks[firstKey] = bg.starts[0].root
		delete(bg.blocks, firstKey)
		bg1.add(bg)
	}
	return bg1, removedBlocks, expectFail
}

const TEST_DOWNLOAD_TIMEOUT = time.Minute // arbitrary value, actually
const TEST_MAX_SIZE_1 = 1024 * 1024 * 1024
const TEST_MAX_SIZE_2 = 1024 * 1024
const TEST_MAX_SIZE_3 = 1024

func (bs *testBitswapState) DataConfig() map[BitswapDataTag]BitswapDataConfig {
	return map[BitswapDataTag]BitswapDataConfig{
		0: {maxSize: TEST_MAX_SIZE_1, downloadTimeout: TEST_DOWNLOAD_TIMEOUT},
		1: {maxSize: TEST_MAX_SIZE_2, downloadTimeout: TEST_DOWNLOAD_TIMEOUT},
		2: {maxSize: TEST_MAX_SIZE_3, downloadTimeout: TEST_DOWNLOAD_TIMEOUT},
	}
}

func TestBitswapDownload(t *testing.T) {
	seed := time.Now().Unix()
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))
	empty := cid.NewSet()
	for i := 0; i < 1000; i++ {
		bg1, removedBlocks, expectFail := genLargeBlockGroup(r)
		testBitswapDownloadDo(t, r, bg1, empty, removedBlocks, expectFail)
		if t.Failed() {
			bg1.print()
			break
		}
	}
}

func TestBitswapDownloadPrepoluated(t *testing.T) {
	seed := time.Now().Unix()
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))
	for i := 0; i < 1000; i++ {
		bg1, removedBlocks, expectFail := genLargeBlockGroup(r)
		prepopulated := cid.NewSet()
		nHalved := len(bg1.blocks) / 2
		if nHalved > 0 {
			prepopulatedIxs := make([]int, r.Intn(nHalved)+1)
			for ix := 0; ix < len(prepopulatedIxs); ix++ {
				prepopulatedIxs[ix] = r.Intn(len(bg1.blocks))
			}
			j := 0
			ix := 0
			for k := range bg1.blocks {
				if j == prepopulatedIxs[ix] {
					if _, has := removedBlocks[k]; has {
						prepopulatedIxs[ix]++
					} else {
						prepopulated.Add(k)
						ix++
						if ix == len(prepopulatedIxs) {
							break
						}
					}
				}
				j++
			}
		}
		testBitswapDownloadDo(t, r, bg1, prepopulated, removedBlocks, expectFail)
		if t.Failed() {
			bg1.print()
			break
		}
	}
}
