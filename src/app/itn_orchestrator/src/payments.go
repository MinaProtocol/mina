package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"itn_json_types"
	"math"
)

type PaymentSubParams struct {
	ExperimentName string                       `json:"experimentName"`
	Tps            float64                      `json:"tps"`
	MinTps         float64                      `json:"minTps"`
	DurationMin    int                          `json:"durationMin"`
	MaxFee         uint64                       `json:"maxFee"`
	MinFee         uint64                       `json:"minFee"`
	Amount         uint64                       `json:"amount"`
	Receiver       itn_json_types.MinaPublicKey `json:"receiver"`
}

type PaymentParams struct {
	PaymentSubParams
	FeePayers []itn_json_types.MinaPrivateKey `json:"feePayers"`
	Nodes     []NodeAddress                   `json:"nodes"`
}

type ScheduledPaymentsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func PaymentKeygenRequirements(gap int, params PaymentSubParams) (int, uint64) {
	maxParticipants := int(math.Ceil(params.Tps / params.MinTps))
	txCost := params.MaxFee + params.Amount
	tpsGap := uint64(math.Round(params.Tps * float64(gap)))
	totalTxs := uint64(math.Ceil(float64(params.DurationMin) * 60 * params.Tps))
	balance := 3 * txCost * totalTxs
	keys := maxParticipants + int(tpsGap)*2
	return keys, balance
}

func schedulePaymentsDo(config Config, params PaymentParams, nodeAddress NodeAddress, batchIx int, tps float64, feePayers []itn_json_types.MinaPrivateKey) (string, error) {
	paymentInput := PaymentsDetails{
		DurationMin: params.DurationMin,
		Tps:         tps,
		MemoPrefix:  fmt.Sprintf("%s-%d", params.ExperimentName, batchIx),
		MaxFee:      params.MaxFee,
		MinFee:      params.MinFee,
		Amount:      params.Amount,
		Receiver:    params.Receiver,
		Senders:     feePayers,
	}
	handle, err := SchedulePaymentsGql(config, nodeAddress, paymentInput)
	if err == nil {
		config.Log.Infof("scheduled payment batch %d with tps %f for %s: %s", batchIx, tps, nodeAddress, handle)
	}
	return handle, err
}

func SchedulePayments(config Config, params PaymentParams, output func(ScheduledPaymentsReceipt)) error {
	tps, nodes := selectNodes(params.Tps, params.MinTps, params.Nodes)
	feePayersPerNode := len(params.FeePayers) / len(nodes)
	successfulNodes := make([]NodeAddress, 0, len(nodes))
	remTps := params.Tps
	remFeePayers := params.FeePayers
	var err error
	for nodeIx, nodeAddress := range nodes {
		feePayers := remFeePayers[:feePayersPerNode]
		var handle string
		handle, err = schedulePaymentsDo(config, params, nodeAddress, len(successfulNodes), tps, feePayers)
		if err != nil {
			config.Log.Warnf("error scheduling payments for %s: %v", nodeAddress, err)
			n := len(nodes) - nodeIx - 1
			if n > 0 {
				tps = remTps / float64(n)
				feePayersPerNode = len(remFeePayers) / n
			}
			continue
		}
		successfulNodes = append(successfulNodes, nodeAddress)
		remFeePayers = remFeePayers[feePayersPerNode:]
		remTps -= tps
		output(ScheduledPaymentsReceipt{
			Address: nodeAddress,
			Handle:  handle,
		})
	}
	if err != nil {
		// last schedule payment request didn't work well
		for _, nodeAddress := range successfulNodes {
			handle, err2 := schedulePaymentsDo(config, params, nodeAddress, len(successfulNodes), tps, remFeePayers)
			if err2 != nil {
				config.Log.Warnf("error scheduling second batch of payments for %s: %v", nodeAddress, err2)
				continue
			}
			output(ScheduledPaymentsReceipt{
				Address: nodeAddress,
				Handle:  handle,
			})
			return nil
		}
	}
	return err
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
