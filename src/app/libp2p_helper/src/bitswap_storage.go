package codanet

import (
	"fmt"

	lmdbbs "github.com/georgeee/go-bs-lmdb"
	"github.com/ipfs/go-cid"
	"github.com/multiformats/go-multihash"
)

type RootBlockStatus int

const (
	Partial RootBlockStatus = iota
	Full
	Deleting
)

type BitswapStorage interface {
	GetStatus(key [32]byte) (RootBlockStatus, error)
	SetStatus(key [32]byte, value RootBlockStatus) error
	DeleteStatus(key [32]byte) error
	DeleteBlocks(keys [][32]byte) error
	ViewBlock(key [32]byte, callback func([]byte) error) error
}

type BitswapStorageLmdb lmdbbs.Blockstore

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

func statusKey(key [32]byte) []byte {
	return append([]byte{BS_STATUS_PREFIX}, key[:]...)
}

func blockKey(key []byte) []byte {
	return append([]byte{BS_BLOCK_PREFIX}, key...)
}

func (bs_ *BitswapStorageLmdb) ViewBlock(key [32]byte, callback func([]byte) error) error {
	bs := (*lmdbbs.Blockstore)(bs_)
	return bs.View(BlockHashToCid(key), callback)
}

func (bs_ *BitswapStorageLmdb) GetStatus(key [32]byte) (res RootBlockStatus, err error) {
	bs := (*lmdbbs.Blockstore)(bs_)
	r, err := bs.GetData(statusKey(key))
	if err != nil {
		return
	}
	res, err = UnmarshalRootBlockStatus(r)
	return
}

func (bs_ *BitswapStorageLmdb) DeleteStatus(key [32]byte) error {
	bs := (*lmdbbs.Blockstore)(bs_)
	return bs.PutData(statusKey(key), func(prevVal []byte, exists bool) ([]byte, bool, error) {
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

func (bs_ *BitswapStorageLmdb) SetStatus(key [32]byte, newStatus RootBlockStatus) error {
	bs := (*lmdbbs.Blockstore)(bs_)
	return bs.PutData(statusKey(key), func(prevVal []byte, exists bool) ([]byte, bool, error) {
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
func (bs_ *BitswapStorageLmdb) DeleteBlocks(keys [][32]byte) error {
	bs := (*lmdbbs.Blockstore)(bs_)
	cids := make([]cid.Cid, len(keys))
	for i, key := range keys {
		cids[i] = BlockHashToCid(key)
	}
	return bs.DeleteMany(cids)
}

const (
	BS_BLOCK_PREFIX byte = iota
	BS_STATUS_PREFIX
)

var MULTI_HASH_CODE = multihash.Names["blake2b-256"]

func cidToKeyMapper(id cid.Cid) []byte {
	mh, err := multihash.Decode(id.Hash())
	if err == nil && mh.Code == MULTI_HASH_CODE && id.Prefix().Codec == cid.Raw {
		return blockKey(mh.Digest)
	}
	return nil
}

// BlockHashToCidSuffix is a function useful for debug output
func BlockHashToCidSuffix(h [32]byte) string {
	s := BlockHashToCid(h).String()
	return s[len(s)-6:]
}

func BlockHashToCid(h [32]byte) cid.Cid {
	mh, _ := multihash.Encode(h[:], MULTI_HASH_CODE)
	return cid.NewCidV1(cid.Raw, mh)
}

func keyToCidMapper(key []byte) (id cid.Cid) {
	if len(key) == 33 && key[0] == BS_BLOCK_PREFIX {
		mh, _ := multihash.Encode(key[1:], MULTI_HASH_CODE)
		id = cid.NewCidV1(cid.Raw, mh)
	}
	return
}
