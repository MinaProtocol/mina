package itn_orchestrator

import (
	"encoding/json"
	"fmt"
)

type StopParams struct {
	Receipts []ScheduledPaymentsReceipt
}

func StopTransactions(config Config, params StopParams) error {
	for _, receipt := range params.Receipts {
		client, err := config.GetGqlClient(config.Ctx, receipt.Address)
		if err != nil {
			return fmt.Errorf("failed to create a client for %s: %v", receipt.Address, err)
		}
		resp, err := StopTransactionsGql(config.Ctx, client, receipt.Handle)
		config.Log.Infof("stop scheduled transactions on %s: %s (%v)", receipt.Address, resp, err)
	}
	return nil
}

type StopAction struct{}

func (StopAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params StopParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return StopTransactions(config, params)
}

var _ Action = StopAction{}
