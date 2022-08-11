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
	exchange "github.com/ipfs/go-ipfs-exchange-interface"
	ipld "github.com/ipfs/go-ipld-format"
)

type bitswapDeleteCmd struct {
	rootIds []root
}

type bitswapAddCmd struct {
	tag  BitswapDataTag
	data []byte
}

type bitswapDownloadCmd struct {
	tag     BitswapDataTag
	rootIds []root
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

func announceNewRootBlock(ctx context.Context, engine *bitswap.Bitswap, statusStorage codanet.BitswapStorage, bs map[BitswapBlockLink][]byte, root BitswapBlockLink) error {
	err := statusStorage.SetStatus(ctx, root, codanet.Partial)
	if err != nil {
		return err
	}

	for h, b := range bs {
		bitswapLogger.Debugf("Publishing block %s (%d bytes)", codanet.BlockHashToCidSuffix(h), len(b))
		block, _ := blocks.NewBlockWithCid(b, codanet.BlockHashToCid(h))
		err = engine.NotifyNewBlocks(ctx, block)
		if err != nil {
			return err
		}
	}
	return statusStorage.SetStatus(ctx, root, codanet.Full)
}

func (bs *BitswapCtx) deleteRoot(root BitswapBlockLink) error {
	if err := bs.storage.SetStatus(bs.ctx, root, codanet.Deleting); err != nil {
		return err
	}
	ClearRootDownloadState(bs, root)
	allDescendants := []BitswapBlockLink{root}
	viewBlockF := func(b []byte) error {
		links, _, err := ReadBitswapBlock(b)
		if err == nil {
			for _, l := range links {
				var l2 BitswapBlockLink
				copy(l2[:], l[:])
				allDescendants = append(allDescendants, l2)
			}
		}
		return err
	}
	for _, block := range allDescendants {
		if err := bs.storage.ViewBlock(bs.ctx, block, viewBlockF); err != nil && err != (ipld.ErrNotFound{Cid: codanet.BlockHashToCid(block)}) {
			return err
		}
	}
	if err := bs.storage.DeleteBlocks(bs.ctx, allDescendants); err != nil {
		return err
	}
	return bs.storage.DeleteStatus(bs.ctx, root)
}

func ClearRootDownloadState(bs BitswapState, root root) {
	rootStates := bs.RootDownloadStates()
	state, has := rootStates[root]
	if !has {
		return
	}
	nodeParams := bs.NodeDownloadParams()
	delete(rootStates, root)
	state.allDescendants.ForEach(func(c cid.Cid) error {
		np, hasNp := nodeParams[c]
		if hasNp {
			delete(np, root)
			if len(np) == 0 {
				delete(nodeParams, c)
			}
		}
		return nil
	})
	state.cancelF()
}

func (bs *BitswapCtx) SendResourceUpdate(type_ ipc.ResourceUpdateType, root root) {
	bs.SendResourceUpdates(type_, root)
}
func (bs *BitswapCtx) SendResourceUpdates(type_ ipc.ResourceUpdateType, roots ...root) {
	// Non-blocking upcall sending
	select {
	case bs.outMsgChan <- mkResourceUpdatedUpcall(type_, roots):
	default:
		for _, root := range roots {
			bitswapLogger.Errorf("Failed to send resource update of type %d"+
				" for %s (message queue is full)",
				type_, codanet.BlockHashToCidSuffix(root))
		}
	}
}

func (bs *BitswapCtx) Context() context.Context {
	return bs.ctx
}
func (bs *BitswapCtx) CheckInvariants() {
	// No checking invariants in production
}
func (bs *BitswapCtx) NodeDownloadParams() map[cid.Cid]map[root][]NodeIndex {
	return bs.nodeDownloadParams
}
func (bs *BitswapCtx) RootDownloadStates() map[root]*RootDownloadState  { return bs.rootDownloadStates }
func (bs *BitswapCtx) MaxBlockSize() int                                { return bs.maxBlockSize }
func (bs *BitswapCtx) DataConfig() map[BitswapDataTag]BitswapDataConfig { return bs.dataConfig }
func (bs *BitswapCtx) DepthIndices() DepthIndices                       { return bs.depthIndices }
func (bs *BitswapCtx) NewSession(downloadTimeout time.Duration) (BlockRequester, context.CancelFunc) {
	ctx, cancelF := context.WithTimeout(bs.ctx, downloadTimeout)
	s := bs.engine.NewSession(ctx)
	return &BitswapBlockRequester{
		fetcher: s,
		ctx:     ctx,
		sink:    bs.blockSink,
	}, cancelF
}
func (bs *BitswapCtx) RegisterDeadlineTracker(root_ root, downloadTimeout time.Duration) {
	go func() {
		<-time.After(downloadTimeout)
		bs.deadlineChan <- root_
	}()
}
func (bs *BitswapCtx) GetStatus(key [32]byte) (codanet.RootBlockStatus, error) {
	return bs.storage.GetStatus(bs.ctx, key)
}
func (bs *BitswapCtx) SetStatus(key [32]byte, value codanet.RootBlockStatus) error {
	return bs.storage.SetStatus(bs.ctx, key, value)
}
func (bs *BitswapCtx) DeleteStatus(key [32]byte) error { return bs.storage.DeleteStatus(bs.ctx, key) }
func (bs *BitswapCtx) DeleteBlocks(keys [][32]byte) error {
	return bs.storage.DeleteBlocks(bs.ctx, keys)
}
func (bs *BitswapCtx) ViewBlock(key [32]byte, callback func([]byte) error) error {
	return bs.storage.ViewBlock(bs.ctx, key, callback)
}

type BitswapBlockRequester struct {
	fetcher exchange.Fetcher
	ctx     context.Context
	sink    chan<- blocks.Block
}

func (br *BitswapBlockRequester) RequestBlocks(ids []cid.Cid) error {
	ch, err := br.fetcher.GetBlocks(br.ctx, ids)
	if err != nil {
		return err
	}
	go func() {
		for v := range ch {
			br.sink <- v
		}
	}()
	return nil
}

// BitswapLoop: Bitswap processing loop
//  Do not launch more than one instance of it
func (bs *BitswapCtx) Loop() {
	configuredCheck := func() {
		if bs.engine == nil || bs.storage == nil {
			panic("BitswapLoop: context not configured")
		}
	}
	for {
		select {
		case <-bs.ctx.Done():
			return
		case root := <-bs.deadlineChan:
			configuredCheck()
			ClearRootDownloadState(bs, root)
		case cmd := <-bs.addCmds:
			configuredCheck()
			blocks, root := SplitDataToBitswapBlocksLengthPrefixedWithTag(bs.maxBlockSize, cmd.data, BlockBodyTag)
			err := announceNewRootBlock(bs.ctx, bs.engine, bs.storage, blocks, root)
			if err == nil {
				bs.SendResourceUpdate(ipc.ResourceUpdateType_added, root)
			} else {
				bitswapLogger.Errorf("Failed to announce root cid %s (%w)", codanet.BlockHashToCidSuffix(root), err)
			}
		case cmd := <-bs.deleteCmds:
			configuredCheck()
			success := []root{}
			for _, root := range cmd.rootIds {
				err := bs.deleteRoot(root)
				if err == nil {
					success = append(success, root)
				} else {
					bitswapLogger.Errorf("Error processing delete request for %s: %w", codanet.BlockHashToCidSuffix(root), err)
				}
			}
			bs.SendResourceUpdates(ipc.ResourceUpdateType_removed, success...)
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
