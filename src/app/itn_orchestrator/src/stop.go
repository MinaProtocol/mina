package itn_orchestrator

import (
	"encoding/json"
	"fmt"
)

type StopParams struct {
	Receipts []ScheduledPaymentsReceipt
}

func StopScheduledTransactions(config Config, params StopParams) error {
	for _, receipt := range params.Receipts {
		client, err := config.GetGqlClient(config.Ctx, receipt.Address)
		if err != nil {
			return fmt.Errorf("failed to created client for %s: %v", receipt.Address, err)
		}
		resp, err := StopPayments(config.Ctx, client, receipt.Handle)
		config.Log.Infof("stopPayments on %s: %s (%v)", receipt.Address, resp, err)
	}
	return nil
}

type StopAction struct{}

func (StopAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params StopParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return StopScheduledTransactions(config, params)
}

var _ Action = StopAction{}
