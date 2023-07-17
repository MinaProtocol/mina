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

func scheduleZkappCommandsDo(config Config, params ZkappCommandParams, nodeAddress NodeAddress, batchIx int, tps float64, zkappsToDeploy, accountQueueSize int, feePayers []itn_json_types.MinaPrivateKey) (string, error) {
	paymentInput := ZkappCommandsDetails{
		MemoPrefix:            fmt.Sprintf("%s-%d", params.ExperimentName, batchIx),
		DurationInMinutes:     params.DurationInMinutes,
		TransactionsPerSecond: tps,
		NumZkappsToDeploy:     zkappsToDeploy,
		NumNewAccounts:        params.NewAccounts,
		FeePayers:             feePayers,
		NoPrecondition:        params.NoPrecondition,
		MinBalanceChange:      formatMina(params.MinBalanceChange),
		MaxBalanceChange:      formatMina(params.MaxBalanceChange),
		InitBalance:           formatMina(1e10 * uint64(params.NewAccounts+1)),
		MinFee:                formatMina(params.MinFee),
		MaxFee:                formatMina(params.MaxFee),
		DeploymentFee:         formatMina(params.DeploymentFee),
		AccountQueueSize:      accountQueueSize,
		MaxCost:               params.MaxCost,
	}
	handle, err := ScheduleZkappCommands(config, nodeAddress, paymentInput)
	if err == nil {
		config.Log.Infof("scheduled zkapp batch %d with tps %f for %s: %s", batchIx, tps, nodeAddress, handle)
	}
	return handle, nil
}

func zkappParams(params ZkappCommandParams, tps float64) (zkappsToDeploy int, accountQueueSize int) {
	zkappsToDeploy, accountQueueSize = params.ZkappsToDeploy, params.AccountQueueSize
	if zkappsToDeploy == 0 {
		tpsGap := int(math.Round(tps * float64(params.Gap)))
		zkappsToDeploy, accountQueueSize = tpsGap*4, tpsGap*3
	}
	return
}

func SendZkappCommands(config Config, params ZkappCommandParams, output func(ScheduledZkappCommandsReceipt)) error {
	if params.ZkappsToDeploy == 0 && params.Gap == 0 {
		return errors.New("either zkappsToDeploy or gap parameters should be specified")
	}
	tps, nodes := selectNodes(params.Tps, params.MinTps, params.Nodes)
	feePayersPerNode := len(params.FeePayers) / len(nodes)
	zkappsToDeploy, accountQueueSize := zkappParams(params, tps)
	successfulNodes := make([]NodeAddress, 0, len(nodes))
	remTps := params.Tps
	remFeePayers := params.FeePayers
	var err error
	for nodeIx, nodeAddress := range nodes {
		feePayers := remFeePayers[:feePayersPerNode]
		var handle string
		handle, err = scheduleZkappCommandsDo(config, params, nodeAddress, len(successfulNodes), tps, zkappsToDeploy, accountQueueSize, feePayers)
		if err != nil {
			config.Log.Warnf("error scheduling zkapp txs for %s: %v", nodeAddress, err)
			n := len(nodes) - nodeIx - 1
			if n > 0 {
				tps = remTps / float64(n)
				feePayersPerNode = len(remFeePayers) / n
				zkappsToDeploy, accountQueueSize = zkappParams(params, tps)
			}
			continue
		}
		successfulNodes = append(successfulNodes, nodeAddress)
		remFeePayers = remFeePayers[feePayersPerNode:]
		remTps -= tps
		output(ScheduledZkappCommandsReceipt{
			Address: nodeAddress,
			Handle:  handle,
		})
	}
	if err != nil {
		// last schedule payment request didn't work well
		for _, nodeAddress := range successfulNodes {
			handle, err2 := scheduleZkappCommandsDo(config, params, nodeAddress, len(successfulNodes), tps, zkappsToDeploy, accountQueueSize, remFeePayers)
			if err2 != nil {
				config.Log.Warnf("error scheduling second batch of zkapp txs for %s: %v", nodeAddress, err2)
				continue
			}
			output(ScheduledZkappCommandsReceipt{
				Address: nodeAddress,
				Handle:  handle,
			})
			return nil
		}
	}
	return err
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
