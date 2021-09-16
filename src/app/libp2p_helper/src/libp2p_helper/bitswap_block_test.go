package main

import (
	"bytes"
	"errors"
	"hash/fnv"
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

func testSplitJoin(maxBlockSize int, data []byte) error {
	blocks, root := SplitDataToBitswapBlocksWithHashF(maxBlockSize, badHash, data)
	res, err := JoinBitswapBlocks(blocks, root)
	if err != nil {
		return err
	}
	if bytes.Compare(res, data) != 0 {
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

func TestBitswapBlockSplitJoin(t *testing.T) {
	require.NoError(t, testSplitJoin(40, []byte("Hello world!")))
	require.NoError(t, testSplitJoin(40, []byte(louis)))
	var data [65536 * 2 * 32]byte
	chunk := badHash([]byte(louis))
	copy(data[:], chunk[:])
	for i := 1; i < len(data)<<5; i++ {
		chunk = badHash(data[(i-1)>>5 : i>>5])
		copy(data[i>>5:], chunk[:])
	}
	require.NoError(t, testSplitJoin(64, data[:93]))
	for i := 35; i <= 128; i++ {
		for j := 1; j <= 1000; j++ {
			t.Logf("i=%d j=%d", i, j)
			err := testSplitJoin(i, data[:j])
			if err != nil {
				t.Error(err)
			}
		}
	}
	require.NoError(t, testSplitJoin(65534*32, data[:]))
	require.NoError(t, testSplitJoin(65535*32, data[:]))
	require.NoError(t, testSplitJoin(65536*32, data[:]))
	for i := 65533; i <= 65540; i++ {
		for j := 65533; j <= 65540; j++ {
			require.NoError(t, testSplitJoin(i*32, data[:j*32]))
		}
	}
	require.NoError(t, testSplitJoin(65536*64, data[:]))
	require.NoError(t, testSplitJoin(100000*32, data[:]))
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
	if err := quick.Check(f, nil); err != nil {
		t.Error(err)
	}
}
