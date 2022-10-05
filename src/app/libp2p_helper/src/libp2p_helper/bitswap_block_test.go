package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"fmt"
	"hash/fnv"
	"math"
	"math/rand"
	"reflect"
	"testing"
	"testing/quick"

	"github.com/stretchr/testify/require"
)

const BAD_HASH_SEED_1 uint64 = 6854716328964733685
const BAD_HASH_SEED_2 uint64 = 7260501629894841770
const BAD_HASH_SEED_3 uint64 = 5145406058976553587
const BAD_HASH_SEED_4 uint64 = 14640219404054247361

// non-cryptographic collission-irresistant hash
// with 32-byte output
func badHash(data []byte) [32]byte {
	h := fnv.New64a()
	h.Write(data)
	s := h.Sum64()
	s1 := s ^ BAD_HASH_SEED_1
	s2 := s ^ BAD_HASH_SEED_2
	s3 := s ^ BAD_HASH_SEED_3
	s4 := s ^ BAD_HASH_SEED_4
	return [32]byte{
		byte(0xff & s1),
		byte(0xff & (s1 >> 8)),
		byte(0xff & (s1 >> 16)),
		byte(0xff & (s1 >> 24)),
		byte(0xff & (s1 >> 32)),
		byte(0xff & (s1 >> 40)),
		byte(0xff & (s1 >> 48)),
		byte(0xff & (s1 >> 56)),
		byte(0xff & s2),
		byte(0xff & (s2 >> 8)),
		byte(0xff & (s2 >> 16)),
		byte(0xff & (s2 >> 24)),
		byte(0xff & (s2 >> 32)),
		byte(0xff & (s2 >> 40)),
		byte(0xff & (s2 >> 48)),
		byte(0xff & (s2 >> 56)),
		byte(0xff & s3),
		byte(0xff & (s3 >> 8)),
		byte(0xff & (s3 >> 16)),
		byte(0xff & (s3 >> 24)),
		byte(0xff & (s3 >> 32)),
		byte(0xff & (s3 >> 40)),
		byte(0xff & (s3 >> 48)),
		byte(0xff & (s3 >> 56)),
		byte(0xff & s4),
		byte(0xff & (s4 >> 8)),
		byte(0xff & (s4 >> 16)),
		byte(0xff & (s4 >> 24)),
		byte(0xff & (s4 >> 32)),
		byte(0xff & (s4 >> 40)),
		byte(0xff & (s4 >> 48)),
		byte(0xff & (s4 >> 56)),
	}
}

type linkIxPair struct {
	id BitswapBlockLink
	ix NodeIndex
}

func testSplitJoinPrefix(maxBlockSize int, data []byte) error {
	blocks, root := SplitDataToBitswapBlocksLengthPrefixedWithHashF(maxBlockSize, badHash, data)
	schema := MkBitswapBlockSchemaLengthPrefixed(maxBlockSize, len(data))
	// len(blocks) < schema.numTotalBlocks is an ok case because some blocks and block subtrees
	// may appear more than once in the tree (in case of data containing repeative subranges)
	if len(blocks) > schema.numTotalBlocks {
		return fmt.Errorf("mismatch of block count: %d > %d", len(blocks), schema.numTotalBlocks)
	}
	di := MkDepthIndices(schema.maxLinksPerBlock, schema.numTotalBlocks)
	for q := []linkIxPair{{id: root}}; len(q) > 0; q = q[1:] {
		id := q[0].id
		ix := q[0].ix
		block, hasBlock := blocks[id]
		if !hasBlock {
			return errors.New("unexpected no block")
		}
		if len(block) != schema.BlockSize(ix) {
			return fmt.Errorf("block doesn't match schema: block size %d != %d",
				len(block), schema.BlockSize(ix))
		}
		links, _, err := ReadBitswapBlock(block)
		if err != nil {
			return err
		}
		if len(links) != schema.LinkCount(ix) {
			return fmt.Errorf("block doesn't match schema: link count %d != %d",
				len(links), schema.LinkCount(ix))
		}
		fstChildIx := di.FirstChildId(ix)
		if fstChildIx < 0 && len(links) > 0 {
			return fmt.Errorf("wrong first child for %d", ix)
		}
		for i, link := range links {
			q = append(q, linkIxPair{id: link, ix: fstChildIx + NodeIndex(i)})
		}
	}
	res, err := JoinBitswapBlocks(blocks, root)
	if err != nil {
		return err
	}
	l := binary.LittleEndian.Uint32(res)
	if int(l) != len(data) {
		return errors.New("unexpected encoded length")
	}
	if !bytes.Equal(res[4:], data) {
		return errors.New("unexpected result of join")
	}
	return nil
}

func testSplitJoin(maxBlockSize int, data []byte) error {
	blocks, root := SplitDataToBitswapBlocksWithHashF(maxBlockSize, badHash, data)
	schema := MkBitswapBlockSchema(maxBlockSize, len(data))
	// len(blocks) < schema.numTotalBlocks is an ok case because some blocks and block subtrees
	// may appear more than once in the tree (in case of data containing repeative subranges)
	if len(blocks) > schema.numTotalBlocks {
		return fmt.Errorf("mismatch of block count: %d > %d", len(blocks), schema.numTotalBlocks)
	}
	res, err := JoinBitswapBlocks(blocks, root)
	if err != nil {
		return err
	}
	if !bytes.Equal(res, data) {
		return errors.New("Unexpected result of join")
	}
	n := 0
	for _, block := range blocks {
		if len(block) == maxBlockSize {
			n++
		}
	}
	if n < len(blocks)-1 {
		return errors.New("More than one block of non-max size")
	}
	return nil
}

const louis = "I see trees of green, red roses too\nI see them bloom for me and you\nAnd I think to myself\nWhat a wonderful world\n\nI see skies of blue and clouds of white\nThe bright blessed days, the dark sacred nights\nAnd I think to myself\nWhat a wonderful world"

func testBitswapBlockSplitJoinImpl(t *testing.T, testImpl func(int, []byte) error) {
	require.NoError(t, testImpl(40, []byte("Hello world!")))
	require.NoError(t, testImpl(40, []byte(louis)))
	var data [65536 * 2 * 32]byte
	chunk := badHash([]byte(louis))
	copy(data[:], chunk[:])
	for i := 1; i < len(data)>>5; i++ {
		chunk = badHash(data[(i-1)<<5 : i<<5])
		copy(data[i<<5:], chunk[:])
	}
	require.NoError(t, testImpl(64, data[:93]))
	for i := 39; i <= 128; i++ {
		for j := 1; j <= 1000; j++ {
			t.Logf("i=%d j=%d", i, j)
			err := testImpl(i, data[:j])
			require.NoError(t, err)
		}
	}
	require.NoError(t, testImpl(65534*32, data[:]))
	require.NoError(t, testImpl(65535*32, data[:]))
	require.NoError(t, testImpl(65536*32, data[:]))
	for i := 65533; i <= 65540; i++ {
		for j := 65533; j <= 65540; j++ {
			require.NoError(t, testImpl(i*32, data[:j*32]))
		}
	}
	require.NoError(t, testImpl(65536*64, data[:]))
	require.NoError(t, testImpl(100000*32, data[:]))
}
func TestBitswapBlockSplitJoin(t *testing.T) {
	testBitswapBlockSplitJoinImpl(t, testSplitJoin)
}

func TestBitswapBlockSplitJoinPrefix(t *testing.T) {
	testBitswapBlockSplitJoinImpl(t, testSplitJoinPrefix)
}

type blockSplitJoinConfig struct {
	maxBlockSize int
	data         []byte
}

func (blockSplitJoinConfig) Generate(r *rand.Rand, size int) reflect.Value {
	data := make([]byte, size)
	_, _ = r.Read(data)
	return reflect.ValueOf(blockSplitJoinConfig{40 + r.Intn(1<<24), data})
}

func TestBitswapBlockSplitJoinQC(t *testing.T) {
	f := func(c blockSplitJoinConfig) bool {
		err := testSplitJoin(c.maxBlockSize, c.data)
		return err == nil
	}
	require.NoError(t, quick.Check(f, nil))
}

func TestBitswapBlockSplitJoinPrefixQC(t *testing.T) {
	f := func(c blockSplitJoinConfig) bool {
		err := testSplitJoinPrefix(c.maxBlockSize, c.data)
		return err == nil
	}
	require.NoError(t, quick.Check(f, nil))
}

func TestDepthIndicesSequence(t *testing.T) {
	lpb := LinksPerBlock(1 << 18)
	di := MkDepthIndices(lpb, math.MaxInt32)
	lastIx := NodeIndex(0)
	for id := NodeIndex(0); id < 10000000; id++ {
		fstChild := di.FirstChildId(id)
		if lastIx+1 == fstChild {
			lastIx = lastIx + NodeIndex(lpb)
		} else {
			t.Fatalf("Unexpected first child %d for id %d", fstChild, id)
		}
	}
}

func TestDepth3(t *testing.T) {
	di := MkDepthIndices(3, 100)
	require.Equal(t, di.FirstChildId(0), NodeIndex(1))
	require.Equal(t, di.FirstChildId(1), NodeIndex(4))
	require.Equal(t, di.FirstChildId(2), NodeIndex(7))
	require.Equal(t, di.FirstChildId(3), NodeIndex(10))
	require.Equal(t, di.FirstChildId(4), NodeIndex(13))
	require.Equal(t, di.FirstChildId(5), NodeIndex(16))
}
