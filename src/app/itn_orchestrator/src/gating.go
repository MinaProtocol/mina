package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
)

type IsolateParams struct {
	Participants []NodeAddress
}

func Isolate(config Config, params IsolateParams) error {
	peers := make([]NetworkPeer, len(params.Participants))
	for i, address := range params.Participants {
		host := string(address[:strings.IndexRune(string(address), ':')])
		nd, has := config.NodeData[address]
		if !has {
			_, _, err := GetGqlClient(config, address)
			if err != nil {
				return fmt.Errorf("failed to authenticate peer %s: %v", address, err)
			}
			nd = config.NodeData[address]
		}
		peers[i] = NetworkPeer{
			Libp2pPort: int(nd.Libp2pPort),
			PeerId:     nd.PeerId,
			Host:       host,
		}
	}
	for i, address := range params.Participants {
		addedPeers := make([]NetworkPeer, len(peers)-1)
		copy(addedPeers, peers[:i])
		copy(addedPeers[i:], peers[i+1:])
		err := UpdateGatingGql(config, address, GatingUpdate{
			AddedPeers:      addedPeers,
			Isolate:         true,
			CleanAddedPeers: true,
			BannedPeers:     make([]NetworkPeer, 0),
			TrustedPeers:    addedPeers,
		})
		if err != nil {
			return err
		}
	}
	return nil
}

type IsolateAction struct{}

func (IsolateAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params IsolateParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return Isolate(config, params)
}

func (IsolateAction) Name() string { return "isolate" }

var _ Action = IsolateAction{}

type ResetGatingParams struct {
	Participants   []NodeAddress
	AddRandomPeers int
}

func ResetGating(config Config, params ResetGatingParams) error {
	peers := make([]NetworkPeer, 0, len(config.NodeData))
	for address, nd := range config.NodeData {
		host := string(address[:strings.IndexRune(string(address), ':')])
		peers = append(peers, NetworkPeer{
			Libp2pPort: int(nd.Libp2pPort),
			PeerId:     nd.PeerId,
			Host:       host,
		})
	}
	gatingUpdate1 := GatingUpdate{
		AddedPeers:      make([]NetworkPeer, 0),
		Isolate:         false,
		CleanAddedPeers: false,
		BannedPeers:     make([]NetworkPeer, 0),
		TrustedPeers:    make([]NetworkPeer, 0),
	}
	for _, address := range params.Participants {
		if err := UpdateGatingGql(config, address, gatingUpdate1); err != nil {
			return fmt.Errorf("failed to update gating for %s: %v", address, err)
		}
	}
	for _, address := range params.Participants {
		var somePeers []NetworkPeer
		if params.AddRandomPeers >= len(peers)-1 {
			somePeers = peers
		} else {
			somePeers = make([]NetworkPeer, 0, params.AddRandomPeers)
			ixs := make([]int, params.AddRandomPeers)
			for i := 0; i < params.AddRandomPeers; i++ {
			outerLoop:
				ix := rand.Intn(len(peers))
				if peers[ix].Host == string(address[:strings.IndexRune(string(address), ':')]) {
					goto outerLoop
				}
				for j := 0; j < i; j++ {
					if ixs[j] == ix {
						goto outerLoop
					}
				}
				ixs[i] = ix
			}
			for _, ix := range ixs {
				somePeers = append(somePeers, peers[ix])
			}
		}
		gatingUpdate2 := GatingUpdate{
			AddedPeers:      somePeers,
			Isolate:         false,
			CleanAddedPeers: false,
			BannedPeers:     make([]NetworkPeer, 0),
			TrustedPeers:    make([]NetworkPeer, 0),
		}
		if err := UpdateGatingGql(config, address, gatingUpdate2); err != nil {
			return err
		}
	}
	return nil
}

type ResetGatingAction struct{}

func (ResetGatingAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params ResetGatingParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return ResetGating(config, params)
}

func (ResetGatingAction) Name() string { return "reset-gating" }

var _ Action = ResetGatingAction{}
