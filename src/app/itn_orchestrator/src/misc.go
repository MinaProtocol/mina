package itn_orchestrator

import (
	"encoding/json"
	"time"
)

type WaitParams struct {
	Minutes int
}

type WaitAction struct{}

func (WaitAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params WaitParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	time.Sleep(time.Minute * time.Duration(params.Minutes))
	return nil
}

var _ Action = WaitAction{}
