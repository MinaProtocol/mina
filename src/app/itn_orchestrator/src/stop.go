package itn_orchestrator

import (
	"encoding/json"
	"errors"
)

type StopParams struct {
	Receipts []ScheduledPaymentsReceipt `json:"receipts"`
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

type StopDaemonParams struct {
	Nodes []NodeAddress `json:"nodes"`
	Clean bool          `json:"clean,omitempty"`
}

func StopDaemon(config Config, params StopDaemonParams) error {
	for _, addr := range params.Nodes {
		resp, err := StopDaemonGql(config, addr, params.Clean, config.StopDaemonDelaySec)
		if err == nil {
			config.Log.Infof("stopped daemon on %s: %s", addr, resp)
		} else {
			config.Log.Warnf("failed to stop daemon on %s: %s", addr, err)
		}
	}
	return nil
}

type StopDaemonAction struct{}

func (StopDaemonAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params StopDaemonParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return StopDaemon(config, params)
}

func (StopDaemonAction) Name() string { return "stop-daemon" }

var _ Action = StopDaemonAction{}
