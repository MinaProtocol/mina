package main

import (
	"codanet"
	"errors"

	"github.com/ipfs/go-cid"
	ipld "github.com/ipfs/go-ipld-format"
)

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

func DeleteRoot(bs BitswapState, root BitswapBlockLink) (BitswapDataTag, error) {
	if err := bs.SetStatus(root, codanet.Deleting); err != nil {
		return 255, err
	}
	var tag BitswapDataTag
	{
		// Determining tag of root being deleted
		state, has := bs.RootDownloadStates()[root]
		if has {
			tag = state.getTag()
		} else {
			err := bs.ViewBlock(root, func(b []byte) error {
				_, fullBlockData, err := ReadBitswapBlock(b)
				if err != nil {
					return err
				}
				if len(fullBlockData) < 5 {
					return errors.New("root block is too short")
				}
				tag = BitswapDataTag(fullBlockData[4])
				return nil
			})
			if err != nil {
				return 255, err
			}
		}
	}
	ClearRootDownloadState(bs, root)
	descendantMap := map[[32]byte]struct{}{root: {}}
	allDescendants := []BitswapBlockLink{root}
	viewBlockF := func(b []byte) error {
		links, _, err := ReadBitswapBlock(b)
		if err == nil {
			for _, l := range links {
				var l2 BitswapBlockLink
				copy(l2[:], l[:])
				_, has := descendantMap[l2]
				if !has {
					descendantMap[l2] = struct{}{}
					allDescendants = append(allDescendants, l2)
				}
			}
		}
		return err
	}
	for i := 0; i < len(allDescendants); i++ {
		block := allDescendants[i]
		if err := bs.ViewBlock(block, viewBlockF); err != nil && err != (ipld.ErrNotFound{Cid: codanet.BlockHashToCid(block)}) {
			return tag, err
		}
	}
	if err := bs.UpdateReferences(root, false, allDescendants...); err != nil {
		return tag, err
	}
	if err := bs.DeleteBlocks(allDescendants); err != nil {
		return tag, err
	}
	return tag, bs.DeleteStatus(root)
}
