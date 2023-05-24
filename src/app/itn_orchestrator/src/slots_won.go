package itn_orchestrator

import (
	"encoding/json"
)

type SlotsWonParams struct {
	Participants []NodeAddress
}

type SlotsWonOutput struct {
	Address  NodeAddress `json:"address"`
	SlotsWon []int       `json:"slots"`
}

func SlotsWon(config Config, params SlotsWonParams, output func(SlotsWonOutput)) error {
	for _, address := range params.Participants {
		resp, slotsQueried, err := SlotsWonGql(config, address)
		if slotsQueried {
			if err != nil {
				return err
			}
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
