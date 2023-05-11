package itn_orchestrator

import (
	"encoding/json"
	"fmt"
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
		client, err := config.GetGqlClient(config.Ctx, address)
		if err != nil {
			return fmt.Errorf("failed to create a client for %s: %v", address, err)
		}
		if config.NodeData[address].IsBlockProducer {
			resp, err := SlotsWonGql(config.Ctx, client)
			if err != nil {
				return fmt.Errorf("failed to get slots for %s: %v", address, err)
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
