package main

import (
	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"

	"github.com/shirou/gopsutil/v3/process"
)

type BandwidthInfoReqT = ipc.Libp2pHelperInterface_BandwidthInfo_Request
type BandwidthInfoReq BandwidthInfoReqT

func fromBandwidthInfoReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.BandwidthInfo()
	return BandwidthInfoReq(i), err
}

func (msg BandwidthInfoReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	stats := app.P2p.BandwidthCounter.GetBandwidthTotals()

	processes, err := process.Processes()

	if err != nil {
		return mkRpcRespError(seqno, err)
	}

	for _, proc := range processes {
		name, err := proc.Name()

		if err != nil {
			return mkRpcRespError(seqno, err)
		}

		if name == "coda-libp2p_helper" {
			usage, err := proc.CPUPercent()

			if err != nil {
				return mkRpcRespError(seqno, err)
			}

			return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
				r, err := m.NewBandwidthInfo()
				panicOnErr(err)
				r.SetInputBandwidth(stats.RateIn)
				r.SetOutputBandwidth(stats.RateOut)
				r.SetCpuUsage(usage)
			})
		}
	}

	return mkRpcRespError(seqno, errors.New("fail to find coda-libp2p_helper, do we rename it?"))
}
