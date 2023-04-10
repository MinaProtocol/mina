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
	AccountCreators   []itn_json_types.MinaPrivateKey
	Nodes             []NodeAddress
}

type ScheduledZkappCommandsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func SendZkappCommands(config Config, params ZkappCommandParams, output func(ScheduledZkappCommandsReceipt)) error {
	feePayersPerNode := len(params.FeePayers) / len(params.Nodes)
	for nodeIx, nodeAddress := range params.Nodes {
		paymentInput := ZkappCommandsDetails{
			DurationInMinutes:        params.DurationInMinutes,
			TransactionsPerSecond:    params.Tps,
			NumNewAccountsToGenerate: params.ZkappsToDeploy,
			NumZkappAccountsToCreate: params.NewAccounts,
			FeePayers:                params.FeePayers[nodeIx*feePayersPerNode : (nodeIx+1)*feePayersPerNode],
			AccountCreator:           params.AccountCreators[nodeIx%len(params.AccountCreators)],
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
