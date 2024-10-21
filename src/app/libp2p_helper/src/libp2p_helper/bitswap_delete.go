package main

import (
	"codanet"
	"errors"

	"github.com/ipfs/go-cid"
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

// getTag retrieves root's tag, whether the root is still being processed
// or its processing was completed
func getTag(bs BitswapState, root BitswapBlockLink) (tag BitswapDataTag, err error) {
	state, has := bs.RootDownloadStates()[root]
	if has {
		tag = state.getTag()
	} else {
		err = bs.ViewBlock(root, func(b []byte) error {
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
	}
	return
}

func DeleteRoot(bs BitswapState, root BitswapBlockLink) (BitswapDataTag, error) {
	if err := bs.SetStatus(root, codanet.Deleting); err != nil {
		return 255, err
	}
	tag, err := getTag(bs, root)
	if err != nil {
		return tag, err
	}
	ClearRootDownloadState(bs, root)

	// Performing breadth-first search (BFS)

	// descendantMap is a "visited" set, to ensure we do not
	// traverse into nodes we once visited
	descendantMap := map[[32]byte]struct{}{root: {}}

	// allDescendants is a list of all discovered nodes,
	// serving as both "queue" to be iterated over during BFS,
	// and as a list of all nodes visited at the end of
	// BFS iteration
	allDescendants := []BitswapBlockLink{root}
	viewBlockF := func(b []byte) error {
		links, _, err := ReadBitswapBlock(b)
		if err == nil {
			for _, l := range links {
				var l2 BitswapBlockLink
				copy(l2[:], l[:])
				_, has := descendantMap[l2]
				// Checking if the nodes was visited before
				if !has {
					descendantMap[l2] = struct{}{}
					// Add an item to BFS queue
					allDescendants = append(allDescendants, l2)
				}
			}
		}
		return err
	}
	// Iteration is done via index-based loop, because underlying
	// array gets extended during iteration, and regular iterator
	// wouldn't see these changes
	for i := 0; i < len(allDescendants); i++ {
		block := allDescendants[i]
		if err := bs.ViewBlock(block, viewBlockF); err != nil && !isBlockNotFound(block, err) {
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
