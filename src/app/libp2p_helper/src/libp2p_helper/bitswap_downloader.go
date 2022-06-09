package main

import (
	"codanet"
	"context"
	"errors"
	"fmt"
	ipc "libp2p_ipc"
	"time"

	blocks "github.com/ipfs/go-block-format"
	"github.com/ipfs/go-cid"
	ipld "github.com/ipfs/go-ipld-format"
	logging "github.com/ipfs/go-log/v2"
)

var bitswapLogger = logging.Logger("mina.helper.bitswap")

type root BitswapBlockLink

// IsValidMaxBlockSize checks that maxBlobSize is not too short
// and has padding that allows to store at least 5 bytes of data in root
// block even in case of root block being full occupied with links
// P.S. all multiples of 32b are valid
func IsValidMaxBlockSize(maxBlobSize int) bool {
	return maxBlobSize >= 7+BITSWAP_BLOCK_LINK_SIZE && (maxBlobSize-2)%BITSWAP_BLOCK_LINK_SIZE >= 5
}

type BitswapDataTag byte

const (
	BlockBodyTag BitswapDataTag = iota
	// EpochLedger // uncomment in future to serve epoch ledger via Bitswap
)

type BitswapDataConfig struct {
	maxSize         int
	downloadTimeout time.Duration
}

type BlockRequester interface {
	RequestBlocks(keys []cid.Cid) error
}

type RootDownloadState struct {
	allDescendants       *cid.Set
	session              BlockRequester
	cancelF              context.CancelFunc
	schema               *BitswapBlockSchema
	tag                  BitswapDataTag
	remainingNodeCounter int
}

type RootParams interface {
	getSchema() *BitswapBlockSchema
	setSchema(*BitswapBlockSchema)
	getTag() BitswapDataTag
}

func (s *RootDownloadState) getSchema() *BitswapBlockSchema {
	return s.schema
}

func (s *RootDownloadState) setSchema(schema *BitswapBlockSchema) {
	if s.schema != nil {
		bitswapLogger.Warn("Double set schema for RootDownloadState")
	}
	s.schema = schema
}

func (s *RootDownloadState) getTag() BitswapDataTag {
	return s.tag
}

type BitswapState interface {
	GetStatus(key [32]byte) (codanet.RootBlockStatus, error)
	SetStatus(key [32]byte, value codanet.RootBlockStatus) error
	DeleteStatus(key [32]byte) error
	DeleteBlocks(keys [][32]byte) error
	ViewBlock(key [32]byte, callback func([]byte) error) error
	NodeDownloadParams() map[cid.Cid]map[root][]NodeIndex
	RootDownloadStates() map[root]*RootDownloadState
	MaxBlockSize() int
	DataConfig() map[BitswapDataTag]BitswapDataConfig
	DepthIndices() DepthIndices
	NewSession(downloadTimeout time.Duration) (BlockRequester, context.CancelFunc)
	RegisterDeadlineTracker(root, time.Duration)
	SendResourceUpdate(type_ ipc.ResourceUpdateType, root root)
	CheckInvariants()
}

// kickStartRootDownload initiates downloading of root block
func kickStartRootDownload(root_ BitswapBlockLink, tag BitswapDataTag, bs BitswapState) {
	bs.CheckInvariants()
	rootCid := codanet.BlockHashToCid(root_)
	nodeDownloadParams := bs.NodeDownloadParams()
	rootDownloadStates := bs.RootDownloadStates()
	_, has := nodeDownloadParams[rootCid]
	if has {
		bitswapLogger.Debugf("Skipping download request for %s (downloading already in progress)", codanet.BlockHashToCidSuffix(root_))
		return // downloading already in progress
	}
	dataConf, hasDC := bs.DataConfig()[tag]
	if !hasDC {
		bitswapLogger.Errorf("Tag %d is not supported by Bitswap downloader", tag)
	}
	if err := bs.SetStatus(root_, codanet.Partial); err != nil {
		bitswapLogger.Debugf("Skipping download request for %s due to status: %w", codanet.BlockHashToCidSuffix(root_), err)
		status, err := bs.GetStatus(root_)
		if err == nil && status == codanet.Full {
			bs.SendResourceUpdate(ipc.ResourceUpdateType_added, root_)
		}
		return
	}
	allDescendants := cid.NewSet()
	allDescendants.Add(rootCid)
	downloadTimeout := dataConf.downloadTimeout
	session, cancelF := bs.NewSession(downloadTimeout)
	np, hasNP := nodeDownloadParams[rootCid]
	if !hasNP {
		np = map[root][]NodeIndex{}
		nodeDownloadParams[rootCid] = np
	}
	np[root_] = append(np[root_], 0)
	rootDownloadStates[root_] = &RootDownloadState{
		allDescendants:       allDescendants,
		session:              session,
		cancelF:              cancelF,
		tag:                  tag,
		remainingNodeCounter: 1,
	}
	handleError := func(err error) {
		bitswapLogger.Errorf("Error initializing block download: %w", err)
		ClearRootDownloadState(bs, root_)
	}
	var rootBlock []byte
	rootBlockViewF := func(b []byte) error {
		rootBlock = make([]byte, len(b))
		copy(rootBlock, b)
		return nil
	}
	if err := bs.ViewBlock(root_, rootBlockViewF); err != nil && err != (ipld.ErrNotFound{Cid: codanet.BlockHashToCid(root_)}) {
		handleError(err)
		return
	}
	hasRootBlock := rootBlock != nil
	if !hasRootBlock {
		if err := session.RequestBlocks([]cid.Cid{rootCid}); err != nil {
			handleError(err)
			return
		}
		bitswapLogger.Debugf("Requested download of %s", codanet.BlockHashToCidSuffix(root_))
	}
	bs.RegisterDeadlineTracker(root_, downloadTimeout)
	if hasRootBlock {
		b, _ := blocks.NewBlockWithCid(rootBlock, rootCid)
		processDownloadedBlock(b, bs)
	}
}

type malformedRoots map[root]error

// processDownloadedBlockStep is a small-step transition of root block retrieval state machine
// It calculates state transition for a single block
func processDownloadedBlockStep(params map[root][]NodeIndex, block blocks.Block, rootParams map[root]RootParams,
	maxBlockSize int, di DepthIndices, tagConfig map[BitswapDataTag]BitswapDataConfig) (map[BitswapBlockLink]map[root][]NodeIndex, malformedRoots) {
	id := block.Cid()
	malformed := make(malformedRoots)
	links, fullBlockData, err := ReadBitswapBlock(block.RawData())
	if err != nil {
		for root := range params {
			malformed[root] = fmt.Errorf("Error reading block %s: %v", id, err)
		}
		return nil, malformed
	}
	children := make(map[BitswapBlockLink]map[root][]NodeIndex)
	for root_, ixs := range params {
		rp, hasRp := rootParams[root_]
		if !hasRp {
			bitswapLogger.Errorf("processBlock: didn't find root state for %s (root %s)",
				id, codanet.BlockHashToCidSuffix(root_))
			continue
		}
		schema := rp.getSchema()
		hasRootIx := false
		for _, ix := range ixs {
			if ix == 0 {
				hasRootIx = true
				break
			}
		}
		if hasRootIx {
			blockData, dataLen, err := ExtractLengthFromRootBlockData(fullBlockData)
			if err == nil && len(blockData) < 1 {
				err = errors.New("error reading tag from block")
			}
			tag := rp.getTag()
			if err == nil {
				tag_ := BitswapDataTag(blockData[0])
				if tag_ != tag {
					err = fmt.Errorf("tag mismatch: %d != %d", tag_, tag)
				}
			}
			if err == nil {
				dataConf, hasDataConf := tagConfig[tag]
				if !hasDataConf {
					err = fmt.Errorf("no tag config for tag %d", tag)
				} else if dataConf.maxSize < dataLen-1 {
					err = fmt.Errorf("data is too large: %d > %d", dataLen-1, dataConf.maxSize)
				}
			}
			if err != nil {
				malformed[root_] = fmt.Errorf("error reading root block %s: %v", id, err)
				continue
			}
			schema_ := MkBitswapBlockSchemaLengthPrefixed(maxBlockSize, dataLen)
			schema = &schema_
			rp.setSchema(schema)
		}
		if schema == nil {
			bitswapLogger.Errorf("Invariant broken for %s (root %s): schema not set for non-root block",
				id, codanet.BlockHashToCidSuffix(root_))
			continue
		}
		for _, ix := range ixs {
			if len(block.RawData()) != schema.BlockSize(ix) {
				malformed[root_] = fmt.Errorf("unexpected size for block #%d (%s) of root %s: %d != %d",
					ix, id, codanet.BlockHashToCidSuffix(root_), len(block.RawData()), schema.BlockSize(ix))
				break
			}
			if len(links) != schema.LinkCount(ix) {
				malformed[root_] = fmt.Errorf("unexpected link count for block %s of root %s: %d != %d (numFullBranchBlocks: %d, ix: %d)",
					id, codanet.BlockHashToCidSuffix(root_), len(links), schema.LinkCount(ix), schema.numFullBranchBlocks, ix)
				break
			}
			fstChildId := di.FirstChildId(ix)
			for childIx, link := range links {
				if children[link] == nil {
					children[link] = make(map[root][]NodeIndex)
				}
				children[link][root_] = append(children[link][root_], fstChildId+NodeIndex(childIx))
			}
		}
	}
	return children, malformed
}

// processDownloadedBlock is a big-step transition of root block retrieval state machine
// It transits state for a single block
func processDownloadedBlock(block blocks.Block, bs BitswapState) {
	bs.CheckInvariants()
	id := block.Cid()
	nodeDownloadParams := bs.NodeDownloadParams()
	rootDownloadStates := bs.RootDownloadStates()
	depthIndices := bs.DepthIndices()
	oldPs, foundRoot := nodeDownloadParams[id]
	delete(nodeDownloadParams, id)
	if !foundRoot {
		bitswapLogger.Warnf("Didn't find node download params for block: %s", id)
		// TODO remove from storage
		return
	}
	rps := make(map[root]RootParams)
	// Can not just pass the `rootDownloadStates` map to processBlock function :(
	for root, ixs := range oldPs {
		rootState, hasRS := rootDownloadStates[root]
		if !hasRS {
			bitswapLogger.Errorf("processDownloadedBlock: didn't find root state for %s (root %s)",
				id, codanet.BlockHashToCidSuffix(root))
			continue
		}
		rootState.remainingNodeCounter = rootState.remainingNodeCounter - len(ixs)
		rps[root] = rootState
	}
	newParams, malformed := processDownloadedBlockStep(oldPs, block, rps, bs.MaxBlockSize(), depthIndices, bs.DataConfig())
	for root, err := range malformed {
		bitswapLogger.Warnf("Block %s of root %s is malformed: %s", id, codanet.BlockHashToCidSuffix(root), err)
		ClearRootDownloadState(bs, root)
		bs.SendResourceUpdate(ipc.ResourceUpdateType_broken, root)
	}

	blocksToProcess := make([]blocks.Block, 0)
	toDownload := make([]cid.Cid, 0)
	var someRootState *RootDownloadState
	for link, ps := range newParams {
		childId := codanet.BlockHashToCid(link)
		np, has := nodeDownloadParams[childId]
		if !has {
			np = make(map[root][]NodeIndex)
			nodeDownloadParams[childId] = np
		}
		for root, ixs := range ps {
			np[root] = append(np[root], ixs...)
			rootState, hasRS := rootDownloadStates[root]
			if !hasRS {
				bitswapLogger.Errorf("processDownloadedBlock (2): didn't find root state for %s (root %s)",
					id, codanet.BlockHashToCidSuffix(root))
				continue
			}
			someRootState = rootState
			rootState.allDescendants.Add(childId)
			rootState.remainingNodeCounter = rootState.remainingNodeCounter + len(ixs)
		}
		var blockBytes []byte
		err := bs.ViewBlock(link, func(b []byte) error {
			blockBytes = make([]byte, len(b))
			copy(blockBytes, b)
			return nil
		})
		if err == nil {
			b, _ := blocks.NewBlockWithCid(blockBytes, childId)
			blocksToProcess = append(blocksToProcess, b)
		} else {
			if err != (ipld.ErrNotFound{Cid: codanet.BlockHashToCid(link)}) {
				// we still schedule blocks for downloading
				// this case should rarely happen in practice
				bitswapLogger.Warnf("Failed to retrieve block %s from storage: %w", childId, err)
			}
			toDownload = append(toDownload, childId)
		}
	}
	if len(toDownload) > 0 {
		// It's fine to use someRootState because all blocks from toDownload
		// inevitably belong to each root, so any will do
		someRootState.session.RequestBlocks(toDownload)
	}
	for root := range oldPs {
		rootState, hasRS := rootDownloadStates[root]
		if hasRS && rootState.remainingNodeCounter == 0 {
			// clean-up
			err := bs.SetStatus(root, codanet.Full)
			if err != nil {
				bitswapLogger.Warnf("Failed to update status of fully downloaded root %s: %s", root, err)
			}
			ClearRootDownloadState(bs, root)
			bs.SendResourceUpdate(ipc.ResourceUpdateType_added, root)
		}
	}
	for _, b := range blocksToProcess {
		processDownloadedBlock(b, bs)
	}
}
