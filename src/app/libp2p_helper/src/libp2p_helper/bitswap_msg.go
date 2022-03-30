package main

import (
	"fmt"
	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
)

type AddResourcePushT = ipc.Libp2pHelperInterface_AddResource
type AddResourcePush AddResourcePushT

func fromAddResourcePush(m ipcPushMessage) (pushMessage, error) {
	i, err := m.AddResource()
	return AddResourcePush(i), err
}

func (m AddResourcePush) handle(app *app) {
	d, err := AddResourcePushT(m).Data()
	if err != nil {
		app.P2p.Logger.Errorf("AddResourcePush.handle: error %w", err)
		return
	}
	app.bitswapCtx.addCmds <- bitswapAddCmd{
		tag:  BitswapDataTag(AddResourcePushT(m).Tag()),
		data: d,
	}
}

type DeleteResourcePushT = ipc.Libp2pHelperInterface_DeleteResource
type DeleteResourcePush DeleteResourcePushT

func fromDeleteResourcePush(m ipcPushMessage) (pushMessage, error) {
	i, err := m.DeleteResource()
	return DeleteResourcePush(i), err
}

func extractRootBlockList(l ipc.RootBlockId_List) ([]root, error) {
	ids := make([]root, 0, l.Len())
	for i := 0; i < l.Len(); i++ {
		id, err := l.At(i).Blake2bHash()
		if err != nil {
			return nil, err
		}
		var link root
		if len(id) != BITSWAP_BLOCK_LINK_SIZE {
			return nil, fmt.Errorf("bitswap block link of unexpected length %d: %v", len(id), id)
		}
		copy(link[:], id)
		ids = append(ids, link)
	}
	return ids, nil
}

func (m DeleteResourcePush) handle(app *app) {
	idsM, err := DeleteResourcePushT(m).Ids()
	var links []root
	if err == nil {
		links, err = extractRootBlockList(idsM)
	}
	if err != nil {
		app.P2p.Logger.Errorf("DeleteResourcePush.handle: error %w", err)
		return
	}
	app.bitswapCtx.deleteCmds <- bitswapDeleteCmd{links}
}

type DownloadResourcePushT = ipc.Libp2pHelperInterface_DownloadResource
type DownloadResourcePush DownloadResourcePushT

func fromDownloadResourcePush(m ipcPushMessage) (pushMessage, error) {
	i, err := m.DownloadResource()
	return DownloadResourcePush(i), err
}

func (m DownloadResourcePush) handle(app *app) {
	idsM, err := DownloadResourcePushT(m).Ids()
	var links []root
	if err == nil {
		links, err = extractRootBlockList(idsM)
	}
	if err != nil {
		app.P2p.Logger.Errorf("DownloadResourcePush.handle: error %w", err)
		return
	}
	app.bitswapCtx.downloadCmds <- bitswapDownloadCmd{
		rootIds: links,
		tag:     BitswapDataTag(DownloadResourcePushT(m).Tag()),
	}
}

type TestDecodeBitswapBlocksReqT = ipc.Libp2pHelperInterface_TestDecodeBitswapBlocks_Request
type TestDecodeBitswapBlocksReq TestDecodeBitswapBlocksReqT

func fromTestDecodeBitswapBlocksReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.TestDecodeBitswapBlocks()
	return TestDecodeBitswapBlocksReq(i), err
}

func (m TestDecodeBitswapBlocksReq) handle(app *app, seqno uint64) *capnp.Message {
	blocks, err := TestDecodeBitswapBlocksReqT(m).Blocks()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	rootBlockId, err := TestDecodeBitswapBlocksReqT(m).RootBlockId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	rawRootHash, err := rootBlockId.Blake2bHash()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	var rootHash [32]byte
	copy(rootHash[:], rawRootHash[:32])

  blockMap := make(map[BitswapBlockLink][]byte)
	err = blockWithIdListForeach(blocks, func(blockWithId ipc.BlockWithId) error {
		rawHash, err := blockWithId.Blake2bHash()
		if err != nil {
			return err
		}
		block, err := blockWithId.Block()
		if err != nil {
			return err
		}

		var hash [32]byte
		copy(hash[:], rawHash[:32])
		blockMap[hash] = block
		return nil
	})
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	data, err := JoinBitswapBlocks(blockMap, rootHash)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewTestDecodeBitswapBlocks()
		panicOnErr(err)
		r.SetDecodedData(data)
	})
}

type TestEncodeBitswapBlocksReqT = ipc.Libp2pHelperInterface_TestEncodeBitswapBlocks_Request
type TestEncodeBitswapBlocksReq TestEncodeBitswapBlocksReqT

func fromTestEncodeBitswapBlocksReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.TestEncodeBitswapBlocks()
	return TestEncodeBitswapBlocksReq(i), err
}

func (m TestEncodeBitswapBlocksReq) handle(app *app, seqno uint64) *capnp.Message {
  mr := TestEncodeBitswapBlocksReqT(m)

	data, err := mr.Data()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

  blocks, rootBlockHash := SplitDataToBitswapBlocks(int(mr.MaxBlockSize()), data)

  return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
    r, err := m.NewTestEncodeBitswapBlocks()
    panicOnErr(err)
    bs, err := r.NewBlocks(int32(len(blocks)))
    panicOnErr(err)
    i := 0
    for hash, block := range blocks {
      b := bs.At(i)
      b.SetBlake2bHash(hash[:])
      b.SetBlock(block)
      i++
    }
    rid, err := r.NewRootBlockId()
    panicOnErr(err)
    rid.SetBlake2bHash(rootBlockHash[:])
  })
}
