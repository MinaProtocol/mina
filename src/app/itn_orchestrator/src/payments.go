package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"itn_json_types"
)

type PaymentParams struct {
	ExperimentName         string
	Tps                    float64
	DurationInMinutes      int
	FeeMax, FeeMin, Amount uint64
	Receiver               itn_json_types.MinaPublicKey
	Senders                []itn_json_types.MinaPrivateKey
	Nodes                  []NodeAddress
}

type ScheduledPaymentsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func SchedulePayments(config Config, params PaymentParams, output func(ScheduledPaymentsReceipt)) error {
	sendersPerNode := len(params.Senders) / len(params.Nodes)
	for nodeIx, nodeAddress := range params.Nodes {
		paymentInput := PaymentsDetails{
			DurationInMinutes:     params.DurationInMinutes,
			TransactionsPerSecond: params.Tps,
			Memo:                  fmt.Sprintf("%s-%d", params.ExperimentName, nodeIx),
			FeeMax:                params.FeeMax,
			FeeMin:                params.FeeMin,
			Amount:                params.Amount,
			Receiver:              params.Receiver,
			Senders:               params.Senders[nodeIx*sendersPerNode : (nodeIx+1)*sendersPerNode],
		}
		client, err := config.GetGqlClient(config.Ctx, nodeAddress)
		if err != nil {
			return fmt.Errorf("error allocating client for %s: %v", nodeAddress, err)
		}
		handle, err := SchedulePaymentsGql(config.Ctx, client, paymentInput)
		if err != nil {
			return fmt.Errorf("error scheduling payments to %s: %v", nodeAddress, err)
		}
		output(ScheduledPaymentsReceipt{
			Address: nodeAddress,
			Handle:  handle,
		})
		config.Log.Infof("scheduled payments for %s: %s", nodeAddress, handle)
	}
	return nil
}

type PaymentsAction struct{}

func (PaymentsAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params PaymentParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return SchedulePayments(config, params, func(receipt ScheduledPaymentsReceipt) {
		output("receipt", receipt, true, false)
	})
}

var _ Action = PaymentsAction{}
