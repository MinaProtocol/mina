package codanet

import (
	"context"
	"fmt"

	blocks "github.com/ipfs/go-block-format"
	"github.com/ipfs/go-cid"
	blockstore "github.com/ipfs/go-ipfs-blockstore"
	"github.com/ledgerwatch/lmdb-go/lmdb"
	"github.com/multiformats/go-multihash"
	lmdbbs "github.com/o1-labs/go-bs-lmdb"
)

type RootBlockStatus int

const (
	Partial RootBlockStatus = iota
	Full
	Deleting
)

type BitswapStorage interface {
	GetStatus(ctx context.Context, key [32]byte) (RootBlockStatus, error)
	SetStatus(ctx context.Context, key [32]byte, value RootBlockStatus) error
	DeleteStatus(ctx context.Context, key [32]byte) error
	DeleteBlocks(ctx context.Context, keys [][32]byte) error
	ViewBlock(ctx context.Context, key [32]byte, callback func([]byte) error) error
	StoreBlocks(ctx context.Context, blocks []blocks.Block) error
}

type BitswapStorageLmdb struct {
	blockstore *lmdbbs.Blockstore
	statusDB   lmdb.DBI
}

func OpenBitswapStorageLmdb(path string) (*BitswapStorageLmdb, error) {
	// 256MiB, a large enough mmap size to make mmap grow() a rare event
	opt := lmdbbs.Options{
		Path:            path,
		InitialMmapSize: 256 << 20,
		CidToKeyMapper:  cidToKeyMapper,
		KeyToCidMapper:  keyToCidMapper,
		MaxDBs:          2,
	}
	blockstore, err := lmdbbs.Open(&opt)
	if err != nil {
		return nil, err
	}
	statusDB, err := blockstore.OpenDB("status")
	if err != nil {
		return nil, fmt.Errorf("failed to create/open lmdb status database: %w", err)
	}
	return &BitswapStorageLmdb{blockstore: blockstore, statusDB: statusDB}, nil
}

func (b *BitswapStorageLmdb) Blockstore() blockstore.Blockstore {
	return b.blockstore
}

func UnmarshalRootBlockStatus(r []byte) (res RootBlockStatus, err error) {
	err = fmt.Errorf("wrong root block status retrieved: %v", r)
	if len(r) != 1 {
		return
	}
	res = RootBlockStatus(r[0])
	if res == Partial || res == Full || res == Deleting {
		err = nil
	}
	return
}

func (bs *BitswapStorageLmdb) StoreBlocks(ctx context.Context, blocks []blocks.Block) error {
	return bs.blockstore.PutMany(ctx, blocks)
}

func (bs *BitswapStorageLmdb) ViewBlock(ctx context.Context, key [32]byte, callback func([]byte) error) error {
	return bs.blockstore.View(ctx, BlockHashToCid(key), callback)
}

func (bs *BitswapStorageLmdb) GetStatus(ctx context.Context, key [32]byte) (res RootBlockStatus, err error) {
	r, err := bs.blockstore.GetData(ctx, bs.statusDB, key[:])
	if err != nil {
		return
	}
	res, err = UnmarshalRootBlockStatus(r)
	return
}

func (bs *BitswapStorageLmdb) DeleteStatus(ctx context.Context, key [32]byte) error {
	return bs.blockstore.PutData(ctx, bs.statusDB, key[:], func(prevVal []byte, exists bool) ([]byte, bool, error) {
		prev, err := UnmarshalRootBlockStatus(prevVal)
		if err != nil {
			return nil, false, err
		}
		if exists && prev != Deleting {
			return nil, false, fmt.Errorf("wrong status deletion from %d", prev)
		}
		return nil, false, nil
	})
}

func isStatusTransitionAllowed(exists bool, prev RootBlockStatus, newStatus RootBlockStatus) bool {
	allowed := newStatus == Partial && (!exists || prev == Partial)
	allowed = allowed || (newStatus == Full && (!exists || prev <= Full))
	allowed = allowed || (newStatus == Deleting && exists)
	return allowed
}

func (bs *BitswapStorageLmdb) SetStatus(ctx context.Context, key [32]byte, newStatus RootBlockStatus) error {
	return bs.blockstore.PutData(ctx, bs.statusDB, key[:], func(prevVal []byte, exists bool) ([]byte, bool, error) {
		var prev RootBlockStatus
		if exists {
			var err error
			prev, err = UnmarshalRootBlockStatus(prevVal)
			if err != nil {
				return nil, false, err
			}
		}
		if !isStatusTransitionAllowed(exists, prev, newStatus) {
			return nil, false, fmt.Errorf("wrong status transition: from %d to %d", prev, newStatus)
		}
		return []byte{byte(newStatus)}, true, nil
	})
}
func (bs *BitswapStorageLmdb) DeleteBlocks(ctx context.Context, keys [][32]byte) error {
	cids := make([]cid.Cid, len(keys))
	for i, key := range keys {
		cids[i] = BlockHashToCid(key)
	}
	return bs.blockstore.DeleteMany(ctx, cids)
}

const (
	BS_BLOCK_PREFIX byte = iota
	BS_STATUS_PREFIX
)

var MULTI_HASH_CODE = multihash.Names["blake2b-256"]

func cidToKeyMapper(id cid.Cid) []byte {
	mh, err := multihash.Decode(id.Hash())
	if err == nil && mh.Code == MULTI_HASH_CODE && id.Prefix().Codec == cid.Raw {
		return mh.Digest
	}
	return nil
}

func keyToCidMapperDo(key []byte) cid.Cid {
	mh, _ := multihash.Encode(key, MULTI_HASH_CODE)
	return cid.NewCidV1(cid.Raw, mh)
}

func BlockHashToCid(h [32]byte) cid.Cid {
	return keyToCidMapperDo(h[:])
}

func keyToCidMapper(key []byte) (id cid.Cid) {
	if len(key) == 32 {
		id = keyToCidMapperDo(key)
	}
	return
}

// BlockHashToCidSuffix is a function useful for debug output
func BlockHashToCidSuffix(h [32]byte) string {
	s := BlockHashToCid(h).String()
	return s[len(s)-6:]
}

func (b *BitswapStorageLmdb) Close() {
	b.blockstore.CloseDB(b.statusDB)
	b.blockstore.Close()
}
