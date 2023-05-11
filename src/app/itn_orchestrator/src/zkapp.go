package itn_orchestrator

import (
	"encoding/json"
	"errors"
	"fmt"
	"itn_json_types"
	"math"
)

type ZkappSubParams struct {
	ExperimentName                                                    string
	Tps, MinTps                                                       float64
	DurationInMinutes                                                 int
	ZkappsToDeploy, NewAccounts, AccountQueueSize, Gap                int
	NoPrecondition, MaxCost                                           bool
	MinBalanceChange, MaxBalanceChange, MinFee, MaxFee, DeploymentFee uint64
}

type ZkappCommandParams struct {
	ZkappSubParams
	FeePayers []itn_json_types.MinaPrivateKey
	Nodes     []NodeAddress
}

type ScheduledZkappCommandsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func ZkappKeygenRequirements(params ZkappSubParams) (int, uint64) {
	maxParticipants := int(math.Ceil(params.Tps / params.MinTps))
	initBalance := 1e10 * uint64(params.NewAccounts+1)
	txCost := params.MaxBalanceChange + params.MaxFee
	tpsGap := uint64(math.Round(params.Tps * float64(params.Gap)))
	totalTxs := uint64(math.Ceil(float64(params.DurationInMinutes) * 60 * params.Tps))
	balance := 3 * ((initBalance+params.DeploymentFee)*tpsGap*3 + txCost*totalTxs)
	keys := maxParticipants + int(tpsGap)*2
	return keys, balance
}

func SendZkappCommands(config Config, params ZkappCommandParams, output func(ScheduledZkappCommandsReceipt)) error {
	tps, nodes := selectNodes(params.Tps, params.MinTps, params.Nodes)
	zkappsToDeploy, accountQueueSize := params.ZkappsToDeploy, params.AccountQueueSize
	feePayersPerNode := len(params.FeePayers) / len(nodes)
	if zkappsToDeploy == 0 {
		if params.Gap == 0 {
			return errors.New("either zkappsToDeploy or gap parameters should be specified")
		}
		gap := params.Gap
		tpsGap := int(math.Round(tps * float64(gap)))
		zkappsToDeploy, accountQueueSize = tpsGap*4, tpsGap*3
	}
	initBalance := 1e10 * uint64(params.NewAccounts+1)
	for nodeIx, nodeAddress := range nodes {
		paymentInput := ZkappCommandsDetails{
			MemoPrefix:            params.ExperimentName,
			DurationInMinutes:     params.DurationInMinutes,
			TransactionsPerSecond: tps,
			NumZkappsToDeploy:     zkappsToDeploy,
			NumNewAccounts:        params.NewAccounts,
			FeePayers:             params.FeePayers[nodeIx*feePayersPerNode : (nodeIx+1)*feePayersPerNode],
			NoPrecondition:        params.NoPrecondition,
			MinBalanceChange:      formatMina(params.MinBalanceChange),
			MaxBalanceChange:      formatMina(params.MaxBalanceChange),
			InitBalance:           formatMina(initBalance),
			MinFee:                formatMina(params.MinFee),
			MaxFee:                formatMina(params.MaxFee),
			DeploymentFee:         formatMina(params.DeploymentFee),
			AccountQueueSize:      accountQueueSize,
			MaxCost:               params.MaxCost,
		}
		client, err := config.GetGqlClient(config.Ctx, nodeAddress)
		if err != nil {
			return fmt.Errorf("error allocating client for %s: %v", nodeAddress, err)
		}
		handle, err := ScheduleZkappCommands(config.Ctx, client, paymentInput)
		if err != nil {
			return fmt.Errorf("error scheduling payments to %s: %v", nodeAddress, err)
		}
		output(ScheduledZkappCommandsReceipt{
			Address: nodeAddress,
			Handle:  handle,
		})
		config.Log.Infof("scheduled payments for %s: %s", nodeAddress, handle)
	}
	return nil
}

type ZkappCommandsAction struct{}

func (ZkappCommandsAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params ZkappCommandParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return SendZkappCommands(config, params, func(receipt ScheduledZkappCommandsReceipt) {
		output("receipt", receipt, true, false)
		output("participant", receipt.Address, true, false)
	})
}

func (ZkappCommandsAction) Name() string { return "zkapp-txs" }

var _ Action = ZkappCommandsAction{}
