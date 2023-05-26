package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"itn_json_types"
)

type ZkappCommandParams struct {
	ExperimentName    string
	Tps               float64
	DurationInMinutes int
	ZkappsToDeploy    int
	NewAccounts       int
	FeePayers         []itn_json_types.MinaPrivateKey
	Nodes             []NodeAddress
	NoPrecondition    bool
	MinBalanceChange  string
	MaxBalanceChange  string
	InitBalance       string
	MinFee            string
	MaxFee            string
	DeploymentFee     string
	AccountQueueSize  int
}

type ScheduledZkappCommandsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func SendZkappCommands(config Config, params ZkappCommandParams, output func(ScheduledZkappCommandsReceipt)) error {
	feePayersPerNode := len(params.FeePayers) / len(params.Nodes)
	for nodeIx, nodeAddress := range params.Nodes {
		paymentInput := ZkappCommandsDetails{
			MemoPrefix:            params.ExperimentName,
			DurationInMinutes:     params.DurationInMinutes,
			TransactionsPerSecond: params.Tps,
			NumZkappsToDeploy:     params.ZkappsToDeploy,
			NumNewAccounts:        params.NewAccounts,
			FeePayers:             params.FeePayers[nodeIx*feePayersPerNode : (nodeIx+1)*feePayersPerNode],
			NoPrecondition:        params.NoPrecondition,
			MinBalanceChange:      params.MinBalanceChange,
			MaxBalanceChange:      params.MaxBalanceChange,
			InitBalance:           params.InitBalance,
			MinFee:                params.MinFee,
			MaxFee:                params.MaxFee,
			DeploymentFee:         params.DeploymentFee,
			AccountQueueSize:      params.AccountQueueSize,
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
	})
}

var _ Action = ZkappCommandsAction{}
