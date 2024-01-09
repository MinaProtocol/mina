package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"math"
)

type SlotsWonParams struct {
	Nodes []NodeAddress `json:"nodes"`
}

type SlotsWonOutput struct {
	Address  NodeAddress `json:"address"`
	SlotsWon []int       `json:"slots"`
}

func SlotsWon(config Config, params SlotsWonParams, output func(SlotsWonOutput)) error {
	for _, address := range params.Nodes {
		resp, slotsQueried, err := SlotsWonGql(config, address)
		if err != nil {
			config.Log.Warnf("failed to query slots won from %s: %s", address, err)
			continue
		}
		if slotsQueried {
			output(SlotsWonOutput{SlotsWon: resp, Address: address})
		} else {
			config.Log.Infof("not querying slots won for node %s", address)
		}
	}
	return nil
}

type SlotsWonAction struct{}

func (SlotsWonAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params SlotsWonParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return SlotsWon(config, params, func(swo SlotsWonOutput) {
		output("slotsWon", swo, true, false)
	})
}

func (SlotsWonAction) Name() string { return "slots-won" }

var _ Action = SlotsWonAction{}

type MajorityStakeCheckParams struct {
	Threshold float64          `json:"threshold"`
	SlotsWon  []SlotsWonOutput `json:"slotsWon"`
}

func MajorityStakeCheck(config Config, params MajorityStakeCheckParams) error {
	threshold := params.Threshold
	allSlots := map[int]struct{}{}
	minSlot := math.MaxInt
	maxSlot := 0
	for _, slotsWon := range params.SlotsWon {
		for _, s := range slotsWon.SlotsWon {
			allSlots[s] = struct{}{}
			if s < minSlot {
				minSlot = s
			}
			if s > maxSlot {
				maxSlot = s
			}
		}
	}
	slotRange := maxSlot - minSlot + 1
	proportion := float64(len(allSlots)) / float64(slotRange)
	if proportion < threshold {
		return fmt.Errorf("proportion %f of slots covered by queried nodes is lower than threshold %f", proportion, threshold)
	}
	return nil
}

type MajorityStakeCheckAction struct{}

func (MajorityStakeCheckAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params MajorityStakeCheckParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return MajorityStakeCheck(config, params)
}

func (MajorityStakeCheckAction) Name() string { return "majority-stake-check" }

var _ Action = MajorityStakeCheckAction{}
