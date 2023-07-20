package itn_orchestrator

import (
	"encoding/json"
	"errors"
)

type StopParams struct {
	Receipts []ScheduledPaymentsReceipt
}

func StopTransactions(config Config, params StopParams) error {
	errs := []error{}
	for _, receipt := range params.Receipts {
		resp, err := StopTransactionsGql(config, receipt.Address, receipt.Handle)
		if err == nil {
			config.Log.Infof("stopped scheduled transactions at %s on %s: %s", receipt.Handle, receipt.Address, resp)
		} else {
			errs = append(errs, err)
		}
	}
	if len(errs) > 0 {
		return errors.Join(errs...)
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

func (StopAction) Name() string { return "stop" }

var _ Action = StopAction{}
