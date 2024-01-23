package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"sort"

	"golang.org/x/crypto/blake2b"
)

const BITSWAP_BLOCK_LINK_SIZE = blake2b.Size256

type BitswapBlockLink = [BITSWAP_BLOCK_LINK_SIZE]byte

func SplitDataToBitswapBlocks(maxBlockDataSize int, data []byte) (map[BitswapBlockLink][]byte, BitswapBlockLink) {
	return SplitDataToBitswapBlocksWithHashF(maxBlockDataSize, func(b []byte) BitswapBlockLink {
		return blake2b.Sum256(b)
	}, data)
}

type BitswapBlockSchema struct {
	numTotalBlocks               int
	numFullBranchBlocks          int
	numLinksInPartialBranchBlock int
	lastLeafBlockDataSize        int
	maxBlockDataSize             int
	maxLinksPerBlock             int
}

func (s BitswapBlockSchema) String() string {
	return fmt.Sprintf("{total: %d, fullLink: %d, lastLinkCount: %d, lastLeafBlockDataSize: %d, maxBlockDataSize: %d, linksPerBlock: %d}",
		s.numTotalBlocks, s.numFullBranchBlocks, s.numLinksInPartialBranchBlock, s.lastLeafBlockDataSize, s.maxBlockDataSize, s.maxLinksPerBlock)
}

// NodeIndex is an index of a node within a specific block tree
type NodeIndex int

// ExtractLengthFromRootBlockData tries to extract length from root block bytes
// It assumes data section to be at least 4 bytes long and interprets first 4 bytes of data as
// length of the whole data blob encoded into block tree associated with the given root block.
func ExtractLengthFromRootBlockData(data_ []byte) (data []byte, length int, err error) {
	if len(data_) < 4 {
		err = errors.New("data less than 4 bytes long")
		return
	}
	length = int(binary.LittleEndian.Uint32(data_))
	data = data_[4:]
	return
}

func SplitDataToBitswapBlocksLengthPrefixedWithTag(maxBlockDataSize int, data []byte, tag BitswapDataTag) (map[BitswapBlockLink][]byte, BitswapBlockLink) {
	return SplitDataToBitswapBlocksLengthPrefixed(maxBlockDataSize, append([]byte{byte(tag)}, data...))
}

func SplitDataToBitswapBlocksLengthPrefixed(maxBlockDataSize int, data []byte) (map[BitswapBlockLink][]byte, BitswapBlockLink) {
	return SplitDataToBitswapBlocksLengthPrefixedWithHashF(maxBlockDataSize, func(b []byte) BitswapBlockLink {
		return blake2b.Sum256(b)
	}, data)
}

// SplitDataToBitswapBlocksLengthPrefixedWithHashF provides a special version of block encoding
// in which first 4 bytes of data is length of the rest of data
// This extension of format allows to provide stronger guarantees on encoding, especially
// in the case when not all of the blocks are available at once.
func SplitDataToBitswapBlocksLengthPrefixedWithHashF(maxBlockDataSize int, hashF func([]byte) BitswapBlockLink, data []byte) (map[BitswapBlockLink][]byte, BitswapBlockLink) {
	if maxBlockDataSize < 2+BITSWAP_BLOCK_LINK_SIZE+4 {
		panic("Max block size too small")
	}
	if len(data) > math.MaxUint32 {
		panic("data too large")
	}
	l := uint32(len(data))
	dataWL := make([]byte, len(data)+4)
	binary.LittleEndian.PutUint32(dataWL, l)
	copy(dataWL[4:], data)
	return SplitDataToBitswapBlocksWithHashF(maxBlockDataSize, hashF, dataWL)
}

func LinksPerBlock(maxBlockDataSize int) int {
	linksPerBlock := (maxBlockDataSize - 2) / BITSWAP_BLOCK_LINK_SIZE
	if linksPerBlock > 65535 {
		linksPerBlock = 65535
	}
	return linksPerBlock
}

// DepthIndices is a data structure that keeps indicies
// of left-most vertex on each depth of a block tree
type DepthIndices struct {
	indices       []NodeIndex
	linksPerBlock int
}

// MkDepthIndices calculates DepthIndices for a given number of links per block
// up to a maximum number of blocks in Bitswap tree
// This structure can be pre-computed and used for all of processing
// with the same `linksPerBlock` parameter
func MkDepthIndices(linksPerBlock, maxTotalBlocks int) DepthIndices {
	res := []NodeIndex{0}
	for val := 1; int(res[len(res)-1])+val < maxTotalBlocks; val = val * linksPerBlock {
		res = append(res, NodeIndex(int(res[len(res)-1])+val))
	}
	return DepthIndices{indices: res, linksPerBlock: linksPerBlock}
}

// `n` is the total number of bitswap blocks
//   formula for `n` is derived as follows
//   (for s_i the data part of bitswap block i,
//   l_i the number of links in the block i):
//      1. 2 + LINK_SIZE * l_i + s_i <= maxBlockDataSize
//      2. sum_i{1..n} ( 2 + LINK_SIZE * l_i + s_i ) <= n * maxBlockDataSize
//      3. sum_i{1..n} l_i = n - 1 (as each block is referenced by
//         a single link and root block is referenced by none)
//      4. sum_i{1..n} s_i = len(data) (sum of all data parts is
//         equal to the size of the data blob)
//      5. 2 * n + LINK_SIZE * (n - 1) + len(data) <= n * maxBlockDataSize
//         (following from 2., 3. and 4.)
//      6. n >= (len(data) - LINK_SIZE) / (maxBlockDataSize - LINK_SIZE - 2)
func requiredBitswapBlockCount(maxBlockDataSize int, dataLength int) int {
	if dataLength <= maxBlockDataSize-2 {
		return 1
	} else {
		n1 := dataLength - BITSWAP_BLOCK_LINK_SIZE
		n2 := maxBlockDataSize - BITSWAP_BLOCK_LINK_SIZE - 2
		return (n1 + n2 - 1) / n2
	}
}

func MkBitswapBlockSchemaLengthPrefixed(maxBlockDataSize int, dataLength int) BitswapBlockSchema {
	return MkBitswapBlockSchema(maxBlockDataSize, dataLength+4)
}

func MkBitswapBlockSchema(maxBlockDataSize int, dataLength int) BitswapBlockSchema {
	numTotalBlocks := requiredBitswapBlockCount(maxBlockDataSize, dataLength)
	// calculate size of the data chunk in the last block
	//   note that by definition last block contains no links
	//   to calculate last block data chunk size, we subtract
	//   amount of data fit in first (n - 1) blocks from total
	//   length of data
	lastBlockDataSz := dataLength - (maxBlockDataSize-BITSWAP_BLOCK_LINK_SIZE-2)*(numTotalBlocks-1)
	// Maximum number of links that can fit in a single Bitswap block
	maxLinksPerBlock := LinksPerBlock(maxBlockDataSize)
	// number of bitswap blocks containing exactly
	// `linksPerBlock` links
	numFullBranchBlocks := (numTotalBlocks - 1) / maxLinksPerBlock
	numLinksInPartialBranchBlock := numTotalBlocks - 1 - numFullBranchBlocks*maxLinksPerBlock
	return BitswapBlockSchema{
		numTotalBlocks:               numTotalBlocks,
		lastLeafBlockDataSize:        lastBlockDataSz,
		numFullBranchBlocks:          numFullBranchBlocks,
		numLinksInPartialBranchBlock: numLinksInPartialBranchBlock,
		maxBlockDataSize:             maxBlockDataSize,
		maxLinksPerBlock:             maxLinksPerBlock,
	}
}

// FirstChildId returns id of the first child of a node with id.
// Subsequent children of the node will occupy following sequential numbers.
func (di *DepthIndices) FirstChildId(id NodeIndex) NodeIndex {
	ixs := di.indices
	depth := sort.Search(len(ixs), func(i int) bool {
		return ixs[i] > id
	})
	if depth >= len(ixs) || depth == 0 {
		return -1
	}
	return ixs[depth] + (id-ixs[depth-1])*NodeIndex(di.linksPerBlock)
}

func (schema *BitswapBlockSchema) BlockSize(id NodeIndex) int {
	if id == NodeIndex(schema.numTotalBlocks-1) {
		return schema.lastLeafBlockDataSize + 2
	}
	return schema.maxBlockDataSize
}

func (schema *BitswapBlockSchema) LinkCount(id NodeIndex) int {
	flb := NodeIndex(schema.numFullBranchBlocks)
	if id < flb {
		return schema.maxLinksPerBlock
	}
	if id == flb {
		return schema.numLinksInPartialBranchBlock
	}
	return 0
}

// Split data blob to a series of bitswap
// blocks. Each resulting block follows
// the byte format:
//
//  * [2 bytes] number of links n
//  * [n * LINK_SIZE bytes] links (each link is a 256-bit hash)
//  * [up to (maxBlockDataSize - 2 - LINK_SIZE * n) bytes] data
//
// Resulting bitswap block tree is balanced. Tree is
// optimized for breadth-first search (BFS), in particular:
//
//  * Data blobs should be concatenated in BFS order
//  * There exist such `M >= 0` such that for any result of the function
//    first `M` blocks contain exactly `min(maxBlockDataSize / LINK_SIZE, 65535)` links
//    per block, and all blocks from `M + 2` (in the BFS order)
//    contain only data (no links)
// All blocks except for last one (in BFS order) are exactly of `maxBlockDataSize` size.
//
// Returns a map of bitswap blocks, indexed by
// hashes of respective blocks and the root block hash.
func SplitDataToBitswapBlocksWithHashF(maxBlockDataSize int, hashF func([]byte) BitswapBlockLink, data []byte) (map[BitswapBlockLink][]byte, BitswapBlockLink) {
	if maxBlockDataSize <= 2+BITSWAP_BLOCK_LINK_SIZE {
		panic("Max block size too small")
	}
	// Maximum number of links that can fit in a single Bitswap block
	schema := MkBitswapBlockSchema(maxBlockDataSize, len(data))
	linksPerBlock := schema.maxLinksPerBlock
	n := schema.numTotalBlocks
	numFullBranchBlocks := schema.numFullBranchBlocks
	lRem := schema.numLinksInPartialBranchBlock

	res := make(map[BitswapBlockLink][]byte)
	queue := make([]BitswapBlockLink, 0, n)
	addBlock := func(links []BitswapBlockLink, chunk []byte) {
		l := len(links)
		sz := l*BITSWAP_BLOCK_LINK_SIZE + 2 + len(chunk)
		if l > 65535 || sz > maxBlockDataSize {
			panic("DataToBlocks: invalid block produced")
		}
		block := make([]byte, sz)
		binary.LittleEndian.PutUint16(block, uint16(l))
		for i_ := range links {
			// We iterate links in reverse order as they were
			// taken out of queue which has the order reversed
			i := len(links) - i_ - 1
			copy(block[2+BITSWAP_BLOCK_LINK_SIZE*i:], links[i_][:])
		}
		copy(block[2+l*BITSWAP_BLOCK_LINK_SIZE:], chunk)
		blockLink := hashF(block)
		res[blockLink] = block
		queue = append(queue, blockLink)
	}

	// end of data not yet allocated to some block
	dataEnd := len(data) - schema.lastLeafBlockDataSize
	addBlock([]BitswapBlockLink{}, data[dataEnd:])

	if n > 1 {
		// number of bitswap blocks containing exactly
		// `maxBlockDataSize - 2` bytes of data
		dataBlocks := n - numFullBranchBlocks - 1
		if lRem > 0 {
			dataBlocks--
		}
		// Amount of data fitting into data-only block
		dataBlockSz := maxBlockDataSize - 2
		// Adding data-only blocks
		for i := 0; i < dataBlocks; i++ {
			addBlock([]BitswapBlockLink{}, data[dataEnd-dataBlockSz:dataEnd])
			dataEnd = dataEnd - dataBlockSz
		}
		if lRem > 0 {
			// Adding a single block with some links that
			// contains less than `linksPerBlock` links
			dsz := maxBlockDataSize - 2 - lRem*BITSWAP_BLOCK_LINK_SIZE
			addBlock(queue[:lRem], data[dataEnd-dsz:dataEnd])
			queue = queue[lRem:]
			dataEnd = dataEnd - dsz
		}
		dsz := maxBlockDataSize - 2 - linksPerBlock*BITSWAP_BLOCK_LINK_SIZE
		for i := 0; i < numFullBranchBlocks; i++ {
			addBlock(queue[:linksPerBlock], data[dataEnd-dsz:dataEnd])
			queue = queue[linksPerBlock:]
			dataEnd = dataEnd - dsz
		}
	}
	return res, queue[0]
}

// Parses block
func ReadBitswapBlock(block []byte) ([]BitswapBlockLink, []byte, error) {
	if len(block) >= 2 {
		l := int(binary.LittleEndian.Uint16(block))
		prefix := BITSWAP_BLOCK_LINK_SIZE*l + 2
		if len(block) >= prefix {
			links := make([]BitswapBlockLink, l)
			for i := 0; i < l; i++ {
				// Copy relies on fixed size of link
				copy(links[i][:], block[2+i*BITSWAP_BLOCK_LINK_SIZE:])
			}
			return links, block[prefix:], nil
		} else {
			return nil, nil, fmt.Errorf("invalid link count: %d (len=%d)", l, len(block))
		}
	}
	return nil, nil, fmt.Errorf("block is too short: %d", len(block))
}

func JoinBitswapBlocks(blocks map[BitswapBlockLink][]byte, root BitswapBlockLink) ([]byte, error) {
	queue := make([]BitswapBlockLink, 0, len(blocks))
	queue = append(queue, root)
	res := make([][]byte, 0, len(blocks))
	for {
		block, has := blocks[queue[0]]
		if !has {
			return nil, errors.New("didn't find a block")
		}
		links, data, err := ReadBitswapBlock(block)
		if err != nil {
			return nil, err
		}
		queue = append(queue[1:], links...)
		res = append(res, data)

		if len(queue) == 0 {
			break
		}
	}
	return bytes.Join(res, []byte{}), nil
}
