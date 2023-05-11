package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"itn_json_types"
	"math"
)

type PaymentSubParams struct {
	ExperimentName         string
	Tps, MinTps            float64
	DurationInMinutes      int
	FeeMax, FeeMin, Amount uint64
	Receiver               itn_json_types.MinaPublicKey
}

type PaymentParams struct {
	PaymentSubParams
	Senders []itn_json_types.MinaPrivateKey
	Nodes   []NodeAddress
}

type ScheduledPaymentsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func PaymentKeygenRequirements(gap int, params PaymentSubParams) (int, uint64) {
	maxParticipants := int(math.Ceil(params.Tps / params.MinTps))
	txCost := params.FeeMax + params.Amount
	tpsGap := uint64(math.Round(params.Tps * float64(gap)))
	totalTxs := uint64(math.Ceil(float64(params.DurationInMinutes) * 60 * params.Tps))
	balance := 3 * txCost * totalTxs
	keys := maxParticipants + int(tpsGap)*2
	return keys, balance
}

func SchedulePayments(config Config, params PaymentParams, output func(ScheduledPaymentsReceipt)) error {
	tps, nodes := selectNodes(params.Tps, params.MinTps, params.Nodes)
	sendersPerNode := len(params.Senders) / len(nodes)
	for nodeIx, nodeAddress := range nodes {
		paymentInput := PaymentsDetails{
			DurationInMinutes:     params.DurationInMinutes,
			TransactionsPerSecond: tps,
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
		output("participant", receipt.Address, true, false)
	})
}

func (PaymentsAction) Name() string { return "payments" }

var _ Action = PaymentsAction{}
