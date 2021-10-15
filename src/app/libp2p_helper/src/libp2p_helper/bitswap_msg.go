package main

import (
	"fmt"
	ipc "libp2p_ipc"
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
	app.bitswapCtx.addCmds <- bitswapAddCmd{d}
}

type DeleteResourcePushT = ipc.Libp2pHelperInterface_DeleteResource
type DeleteResourcePush DeleteResourcePushT

func fromDeleteResourcePush(m ipcPushMessage) (pushMessage, error) {
	i, err := m.DeleteResource()
	return DeleteResourcePush(i), err
}

func extractRootBlockList(l ipc.RootBlockId_List) ([]BitswapBlockLink, error) {
	ids := make([]BitswapBlockLink, 0, l.Len())
	for i := 0; i < l.Len(); i++ {
		id, err := l.At(i).Blake2bHash()
		if err != nil {
			return nil, err
		}
		var link BitswapBlockLink
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
	var links []BitswapBlockLink
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
	var links []BitswapBlockLink
	if err == nil {
		links, err = extractRootBlockList(idsM)
	}
	if err != nil {
		app.P2p.Logger.Errorf("DownloadResourcePush.handle: error %w", err)
		return
	}
	app.bitswapCtx.downloadCmds <- bitswapDownloadCmd{links}
}
