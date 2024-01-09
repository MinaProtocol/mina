package itn_orchestrator

import (
	"encoding/json"
)

type SetZkappSoftLimitParams struct {
	Nodes []NodeAddress `json:"nodes"`
	Limit *int          `json:"limit"`
}

func SetZkappSoftLimit(config Config, params SetZkappSoftLimitParams, output func(NodeAddress)) error {
	for _, address := range params.Nodes {
		_, err := SetZkappSoftLimitGql(config, address, params.Limit)
		if err == nil {
			output(address)
		} else {
			config.Log.Warnf("Failed to set soft limit to %d for %s: %s", params.Limit, address, err)
		}
	}
	return nil
}

type SetZkappSoftLimitAction struct{}

func (SetZkappSoftLimitAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params SetZkappSoftLimitParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return SetZkappSoftLimit(config, params, func(addr NodeAddress) {
		output("participant", addr, true, false)
	})
}

func (SetZkappSoftLimitAction) Name() string { return "set-zkapp-soft-limit" }

var _ Action = SetZkappSoftLimitAction{}
