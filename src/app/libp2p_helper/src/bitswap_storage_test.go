package codanet

import (
	"context"
	"path"
	"sync"
	"testing"

	blocks "github.com/ipfs/go-block-format"
	"github.com/stretchr/testify/require"
	"golang.org/x/crypto/blake2b"
)

func newTestStorageBlock(t *testing.T, data []byte) (blocks.Block, [32]byte) {
	key := blake2b.Sum256(data)
	b, err := blocks.NewBlockWithCid(data, BlockHashToCid(key))
	require.NoError(t, err)
	return b, key
}

func TestBitswapStorageClosedOperationsFail(t *testing.T) {
	ctx := context.Background()
	bs, err := OpenBitswapStorageLmdb(path.Join(t.TempDir(), "block-db"))
	require.NoError(t, err)
	b, key := newTestStorageBlock(t, []byte("block"))
	require.NoError(t, bs.StoreBlocks(ctx, []blocks.Block{b}))

	bs.Close()
	// Closing again does nothing.
	bs.Close()

	err = bs.ViewBlock(ctx, key, func([]byte) error { return nil })
	require.ErrorIs(t, err, ErrBitswapStorageClosed)
	require.ErrorIs(t, bs.StoreBlocks(ctx, []blocks.Block{b}), ErrBitswapStorageClosed)
	_, err = bs.GetStatus(ctx, key)
	require.ErrorIs(t, err, ErrBitswapStorageClosed)
	require.ErrorIs(t, bs.SetStatus(ctx, key, Full), ErrBitswapStorageClosed)
	require.ErrorIs(t, bs.DeleteStatus(ctx, key), ErrBitswapStorageClosed)
	require.ErrorIs(t, bs.UpdateReferences(ctx, key, true, key), ErrBitswapStorageClosed)
	require.ErrorIs(t, bs.DeleteBlocks(ctx, [][32]byte{key}), ErrBitswapStorageClosed)
}

func TestBitswapStorageCloseDuringOperations(t *testing.T) {
	ctx := context.Background()
	bs, err := OpenBitswapStorageLmdb(path.Join(t.TempDir(), "block-db"))
	require.NoError(t, err)

	var wg sync.WaitGroup
	start := make(chan struct{})
	for w := 0; w < 8; w++ {
		wg.Add(1)
		go func(w int) {
			defer wg.Done()
			<-start
			for i := 0; ; i++ {
				b, key := newTestStorageBlock(t, []byte{byte(w), byte(i), byte(i >> 8)})
				err := bs.StoreBlocks(ctx, []blocks.Block{b})
				if err == nil {
					err = bs.ViewBlock(ctx, key, func([]byte) error { return nil })
				}
				if err != nil {
					require.ErrorIs(t, err, ErrBitswapStorageClosed)
					return
				}
			}
		}(w)
	}
	close(start)
	bs.Close()
	wg.Wait()
}
