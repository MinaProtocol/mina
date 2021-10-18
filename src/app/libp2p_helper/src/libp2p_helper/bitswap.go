package main

import (
	"codanet"
	"context"
	ipc "libp2p_ipc"
	"math"
	"time"

	"capnproto.org/go/capnp/v3"
	"github.com/ipfs/go-bitswap"
	blocks "github.com/ipfs/go-block-format"
	"github.com/ipfs/go-cid"
	blockstore "github.com/ipfs/go-ipfs-blockstore"
	exchange "github.com/ipfs/go-ipfs-exchange-interface"
)

type bitswapDeleteCmd struct {
	rootIds []BitswapBlockLink
}

type bitswapAddCmd struct {
	tag  BitswapDataTag
	data []byte
}

type bitswapDownloadCmd struct {
	tag     BitswapDataTag
	rootIds []BitswapBlockLink
}

type BitswapCtx struct {
	downloadCmds       chan bitswapDownloadCmd
	addCmds            chan bitswapAddCmd
	deleteCmds         chan bitswapDeleteCmd
	engine             *bitswap.Bitswap
	storage            codanet.BitswapStorage
	ctx                context.Context
	blockSink          chan blocks.Block
	nodeDownloadParams map[cid.Cid]map[root][]NodeIndex
	rootDownloadStates map[root]*RootDownloadState
	deadlineChan       chan root
	outMsgChan         chan<- *capnp.Message
	maxBlockSize       int
	dataConfig         map[BitswapDataTag]BitswapDataConfig
	depthIndices       DepthIndices
}

func NewBitswapCtx(ctx context.Context, outMsgChan chan<- *capnp.Message) *BitswapCtx {
	maxBlockSize := 1 << 18 // 256 KiB
	return &BitswapCtx{
		downloadCmds:       make(chan bitswapDownloadCmd, 100),
		addCmds:            make(chan bitswapAddCmd, 100),
		deleteCmds:         make(chan bitswapDeleteCmd, 100),
		ctx:                ctx,
		rootDownloadStates: make(map[root]*RootDownloadState),
		nodeDownloadParams: make(map[cid.Cid]map[root][]NodeIndex),
		blockSink:          make(chan blocks.Block, 100),
		deadlineChan:       make(chan root, 100),
		outMsgChan:         outMsgChan,
		maxBlockSize:       maxBlockSize,
		dataConfig: map[BitswapDataTag]BitswapDataConfig{
			BlockBodyTag: {
				maxSize:         1 << 26, // 64 MiB
				downloadTimeout: time.Minute * 10,
			},
		},
		depthIndices: MkDepthIndices(LinksPerBlock(maxBlockSize), math.MaxInt32),
	}
}

func announceNewRootBlock(engine *bitswap.Bitswap, statusStorage codanet.BitswapStorage, bs map[BitswapBlockLink][]byte, root BitswapBlockLink) error {
	err := statusStorage.SetStatus(root, codanet.Partial)
	if err != nil {
		return err
	}

	for h, b := range bs {
		id := codanet.BlockHashToCid(h)
		bitswapLogger.Debugf("Publishing block %s (%d bytes)", id, len(b))
		block, _ := blocks.NewBlockWithCid(b, id)
		err = engine.HasBlock(block)
		if err != nil {
			return err
		}
	}
	return statusStorage.SetStatus(root, codanet.Full)
}

func (bs *BitswapCtx) deleteRoot(root BitswapBlockLink) error {
	err := bs.storage.SetStatus(root, codanet.Deleting)
	if err != nil {
		return err
	}
	bs.FreeRoot(root)
	allDescedants := []BitswapBlockLink{root}
	for i := 0; i < len(allDescedants); i++ {
		block := allDescedants[i]
		err := bs.storage.ViewBlock(block, func(b []byte) error {
			links, _, err := ReadBitswapBlock(b)
			if err == nil {
				for _, l := range links {
					var l2 BitswapBlockLink
					copy(l2[:], l[:])
					allDescedants = append(allDescedants, l2)
				}
			}
			return err
		})
		if err != nil && err != blockstore.ErrNotFound {
			return err
		}
	}
	return bs.storage.DeleteBlocks(allDescedants)
}

func (bs *BitswapCtx) AsyncDownloadBlocks(ctx context.Context, session exchange.Fetcher, cids []cid.Cid) error {
	ch, err := session.GetBlocks(ctx, cids)
	if err != nil {
		return err
	}
	go func() {
		for v := range ch {
			// bitswapLogger.Debugf("AsyncDownloadBlocks: received block %s (%d bytes)", v.Cid(), len(v.RawData()))
			bs.blockSink <- v
		}
	}()
	return nil
}

func (bs *BitswapCtx) FreeRoot(root root) {
	state, has := bs.rootDownloadStates[root]
	if !has {
		return
	}
	delete(bs.rootDownloadStates, root)
	state.allDescedants.ForEach(func(c cid.Cid) error {
		np, hasNp := bs.nodeDownloadParams[c]
		if hasNp {
			delete(np, root)
			if len(np) == 0 {
				delete(bs.nodeDownloadParams, c)
			}
		}
		return nil
	})
	state.cancelF()
}

func (bs *BitswapCtx) SendResourceUpdate(type_ ipc.ResourceUpdateType, roots ...BitswapBlockLink) {
	// Non-blocking upcall sending
	select {
	case bs.outMsgChan <- mkResourceUpdatedUpcall(type_, roots):
	default:
		for _, root := range roots {
			bitswapLogger.Errorf("Failed to send resource update of type %d"+
				" for %s (message queue is full)",
				type_, codanet.BlockHashToCid(root))
		}
	}
}

func (bs *BitswapCtx) NodeDownloadParams() map[cid.Cid]map[root][]NodeIndex {
	return bs.nodeDownloadParams
}
func (bs *BitswapCtx) RootDownloadStates() map[root]*RootDownloadState  { return bs.rootDownloadStates }
func (bs *BitswapCtx) MaxBlockSize() int                                { return bs.maxBlockSize }
func (bs *BitswapCtx) DataConfig() map[BitswapDataTag]BitswapDataConfig { return bs.dataConfig }
func (bs *BitswapCtx) DepthIndices() DepthIndices                       { return bs.depthIndices }
func (bs *BitswapCtx) Context() context.Context                         { return bs.ctx }
func (bs *BitswapCtx) NewSession(ctx context.Context) exchange.Fetcher {
	return bs.engine.NewSession(ctx)
}
func (bs *BitswapCtx) DeadlineChan() chan<- root { return bs.deadlineChan }
func (bs *BitswapCtx) GetStatus(key [32]byte) (codanet.RootBlockStatus, error) {
	return bs.storage.GetStatus(key)
}
func (bs *BitswapCtx) SetStatus(key [32]byte, value codanet.RootBlockStatus) error {
	return bs.storage.SetStatus(key, value)
}
func (bs *BitswapCtx) DeleteStatus(key [32]byte) error    { return bs.storage.DeleteStatus(key) }
func (bs *BitswapCtx) DeleteBlocks(keys [][32]byte) error { return bs.storage.DeleteBlocks(keys) }
func (bs *BitswapCtx) ViewBlock(key [32]byte, callback func([]byte) error) error {
	return bs.storage.ViewBlock(key, callback)
}

// BitswapLoop: Bitswap processing loop
//  Do not launch more than one instance of it
func (bs *BitswapCtx) Loop() {
	engine := bs.engine
	storage := bs.storage
	configuredCheck := func() {
		if engine == nil || storage == nil {
			panic("BitswapLoop: context not configured")
		}
	}
	for {
		// TODO condition to end the loop?
		select {
		case <-bs.ctx.Done():
			return
		case root := <-bs.deadlineChan:
			configuredCheck()
			bs.FreeRoot(root)
		case cmd := <-bs.addCmds:
			configuredCheck()
			blocks, root := SplitDataToBitswapBlocksLengthPrefixedWithTag(bs.maxBlockSize, cmd.data, BlockBodyTag)
			err := announceNewRootBlock(engine, storage, blocks, root)
			if err == nil {
				bs.SendResourceUpdate(ipc.ResourceUpdateType_added, root)
			} else {
				bitswapLogger.Errorf("Failed to announce root cid %s (%w)", codanet.BlockHashToCid(root), err)
			}
		case cmd := <-bs.deleteCmds:
			configuredCheck()
			success := []BitswapBlockLink{}
			for _, root := range cmd.rootIds {
				err := bs.deleteRoot(root)
				if err == nil {
					err = storage.DeleteStatus(root)
				}
				if err == nil {
					success = append(success, root)
				} else {
					bitswapLogger.Errorf("Error processing delete request for %s: %w", codanet.BlockHashToCid(root), err)
				}
			}
			bs.SendResourceUpdate(ipc.ResourceUpdateType_removed, success...)
		case cmd := <-bs.downloadCmds:
			configuredCheck()
			// We put all ids to map to avoid
			// unneccessary querying in case of id duplicates
			m := make(map[BitswapBlockLink]bool)
			for _, root := range cmd.rootIds {
				m[root] = true
			}
			for root := range m {
				kickStartRootDownload(root, cmd.tag, bs)
			}
		case block := <-bs.blockSink:
			configuredCheck()
			processDownloadedBlock(block, bs)
		}
	}
}
