package main

import (
	"bytes"
	"codanet"
	"container/heap"
	"encoding/binary"
	"math"
	"math/rand"
	"testing"
	"time"

	blocks "github.com/ipfs/go-block-format"
	"github.com/stretchr/testify/require"
)

type blockGroupStart struct {
	root root
	tag  BitswapDataTag
}

type blockGroup struct {
	blocks       map[BitswapBlockLink][]byte
	starts       []blockGroupStart
	maxBlockSize int
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
	return blockGroup{
		starts:       []blockGroupStart{{root: root_, tag: tag}},
		blocks:       blocksRaw,
		maxBlockSize: maxBlockSize,
	}
}

func (bg *blockGroup) addDuplicateOfRoot(r *rand.Rand, rootIx int, tag BitswapDataTag) int {
	n := len(bg.blocks)
	subRoot := bg.starts[rootIx].root
	var subDataLen int
	{
		_, rootBlockData, err := ReadBitswapBlock(bg.blocks[subRoot])
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
		bg.blocks[sbLink] = sb
	}
	newRoot := badHash(rootBlock)
	bg.blocks[newRoot] = rootBlock
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
		blockData := bg.blocks[link]
		block, _ := blocks.NewBlockWithCid(blockData, codanet.BlockHashToCid(link))
		np, hasNP := nodeParams[link]
		if !hasNP {
			panic("unexpected no np")
		}
		delete(nodeParams, link)
		children, malformed_ := processDownloadedBlockImpl(np, block, rootParams, bg.maxBlockSize, di, tagConfig)
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
	maxBlockSize := genMaxBlockSize(r, math.MaxUint8)
	lpb := LinksPerBlock(maxBlockSize)
	lastLinkNodeIx := r.Intn(math.MaxUint8)
	lastLinkNodeCount := 1
	if lpb > 1 {
		lastLinkNodeCount += r.Intn(lpb - 1)
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
	blocks := make(map[BitswapBlockLink][]byte)
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
			blocks[link] = block
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
	blocks[root] = rootBlock
	return blockGroup{
		maxBlockSize: int(proto.maxBlockSize),
		starts:       []blockGroupStart{{root: root, tag: tag}},
		blocks:       blocks,
	}
}

func TestProcessDownloadedBlockImplInvalidStructure(t *testing.T) {
	tagConfig := map[BitswapDataTag]BitswapDataConfig{
		0: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
	}
	seed := time.Now().Unix()
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
		m := tree.execute(r, tagConfig)
		require.Equal(t, 0, len(m))
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

func TestProcessDownloadedBlockImpl(t *testing.T) {
	tagConfig := map[BitswapDataTag]BitswapDataConfig{
		0: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
		1: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
		2: {maxSize: math.MaxInt32, downloadTimeout: time.Minute},
	}
	// seed := time.Now().Unix()
	seed := int64(1634813202)
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))
	for i := 0; i < 1000; i++ {
		// Basic test
		bg1 := genValidBlockGroup(r, 0)
		require.Equal(t, 0, len(bg1.execute(r, tagConfig)))
		// Unknown tag
		root1 := bg1.starts[0].root
		m1 := bg1.execute(r, map[BitswapDataTag]BitswapDataConfig{})
		_, m1HasRoot := m1[root1]
		require.True(t, m1HasRoot && len(m1) >= 1)
		// Duplicate tree as subtree of a new block tree
		bg1.addDuplicateOfRoot(r, 0, 1)
		require.Equal(t, 0, len(bg1.execute(r, tagConfig)))
		// Replace one block with invalid block and back again
		// we do not recalculate links as they are not recalculated
		// during processing
		var link1 BitswapBlockLink
		var block1 []byte
		for link1, block1 = range bg1.blocks {
			if !bytes.Equal(link1[:], root1[:]) {
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
			bg1.blocks[link1] = b
			require.Less(t, 0, len(bg1.execute(r, tagConfig)))
		}
		bg1.blocks[link1] = block1
		root1Block := bg1.blocks[root1]
		bg1.blocks[root1] = root1Block[:5]
		require.Less(t, 0, len(bg1.execute(r, tagConfig)))
		bg1.blocks[root1] = root1Block
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
