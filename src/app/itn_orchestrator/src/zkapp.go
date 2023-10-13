package itn_orchestrator

import (
	"encoding/json"
	"errors"
	"fmt"
	"itn_json_types"
	"math"
)

type ZkappSubParams struct {
	ExperimentName   string  `json:"experimentName"`
	Tps              float64 `json:"tps"`
	MinTps           float64 `json:"minTps"`
	DurationMin      int     `json:"durationMin"`
	MaxFee           uint64  `json:"maxFee"`
	MinFee           uint64  `json:"minFee"`
	ZkappsToDeploy   int     `json:"zkapps"`
	NewAccountRatio  float64 `json:"newAccountRatio"`
	AccountQueueSize int     `json:"queueSize"`
	Gap              int     `json:"gap"`
	NoPrecondition   bool    `json:"noPrecondition"`
	MaxCost          bool    `json:"maxCost"`
	MinBalanceChange uint64  `json:"minBalanceChange"`
	MaxBalanceChange uint64  `json:"maxBalanceChange"`
	DeploymentFee    uint64  `json:"deploymentFee"`
}

type ZkappCommandParams struct {
	ZkappSubParams
	FeePayers []itn_json_types.MinaPrivateKey `json:"feePayers"`
	Nodes     []NodeAddress                   `json:"nodes"`
}

type ScheduledZkappCommandsReceipt struct {
	Address NodeAddress `json:"address"`
	Handle  string      `json:"handle"`
}

func tpsGap(tps float64, gapSec int) int {
	return int(math.Ceil(tps * float64(gapSec)))
}

func ZkappBalanceRequirements(tps float64, p ZkappSubParams) (int, uint64, uint64, uint64) {
	totalZkappsToDeploy, _ := zkappParams(p, tps)
	// new accounts are set to ratio multplied by (number of txs minus zkapp deploying txs)
	newAccounts := int(tps * float64(p.DurationMin*60-totalZkappsToDeploy) * p.NewAccountRatio)
	// not accounting for Birthday paradox, we multiply by three at a later stage for this reason
	maxExpectedUsagesPerNewAccount := float64(p.DurationMin*60) / float64(p.Gap)
	//We multiply by three because by matter of chance some zkapps may generate more new accounts
	newAccountsPerZkapp := int(float64(newAccounts) / float64(totalZkappsToDeploy) * 3)
	balanceDeductedPerUsage := p.MaxBalanceChange * 2
	// We add 1e9 because of account creation fee
	minNewZkappBalance := uint64(maxExpectedUsagesPerNewAccount*float64(balanceDeductedPerUsage))*3 + 1e9
	maxNewZkappBalance := minNewZkappBalance * 3
	// multiply by two for "error factor"
	initBalance := maxNewZkappBalance * (uint64(newAccountsPerZkapp) + 1) * 2
	return newAccounts, minNewZkappBalance, maxNewZkappBalance, initBalance
}

func ZkappKeygenRequirements(initZkappBalance uint64, params ZkappSubParams) (int, uint64) {
	maxParticipants := int(math.Ceil(params.Tps / params.MinTps))
	minTpsGap := tpsGap(params.MinTps, params.Gap)
	// Minimal number of keys allocated per node
	minKeysPerNode := minTpsGap * 2
	minTpsZkappsToDeploy, _ := zkappParams(params, params.MinTps)
	zkappsToDeployPerKey := uint64(minTpsZkappsToDeploy/minKeysPerNode) + 1
	tpsGap := tpsGap(params.Tps, params.Gap)
	keys := maxParticipants + tpsGap*2
	txCost := params.MaxBalanceChange*8 + params.MaxFee
	totalTxs := uint64(math.Ceil(float64(params.DurationMin) * 60 * params.Tps))
	balance := uint64(keys)*zkappsToDeployPerKey*(initZkappBalance+params.DeploymentFee)*2 + 3*txCost*totalTxs
	return keys, balance
}

func ZkappPaymentsInput(params ZkappSubParams, batchIx int, tps float64) ZkappCommandsDetails {
	zkappsToDeploy, accountQueueSize := zkappParams(params, tps)
	newAccounts, minNewZkappBalance, maxNewZkappBalance, initBalance := ZkappBalanceRequirements(tps, params)
	return ZkappCommandsDetails{
		MemoPrefix:         fmt.Sprintf("%s-%d", params.ExperimentName, batchIx),
		DurationMin:        params.DurationMin,
		Tps:                tps,
		NumZkappsToDeploy:  zkappsToDeploy,
		NumNewAccounts:     newAccounts,
		NoPrecondition:     params.NoPrecondition,
		MinBalanceChange:   params.MinBalanceChange,
		MaxBalanceChange:   params.MaxBalanceChange,
		MinNewZkappBalance: minNewZkappBalance,
		MaxNewZkappBalance: maxNewZkappBalance,
		InitBalance:        initBalance,
		MinFee:             params.MinFee,
		MaxFee:             params.MaxFee,
		DeploymentFee:      params.DeploymentFee,
		AccountQueueSize:   accountQueueSize,
		MaxCost:            params.MaxCost,
		MaxAccountUpdates:  2,
	}
}

func scheduleZkappCommandsDo(config Config, params ZkappCommandParams, nodeAddress NodeAddress, batchIx int, tps float64, feePayers []itn_json_types.MinaPrivateKey) (string, error) {
	paymentInput := ZkappPaymentsInput(params.ZkappSubParams, batchIx, tps)
	paymentInput.FeePayers = feePayers
	handle, err := ScheduleZkappCommands(config, nodeAddress, paymentInput)
	if err == nil {
		config.Log.Infof("scheduled zkapp batch %d with tps %f for %s: %s", batchIx, tps, nodeAddress, handle)
	}
	return handle, err
}

func zkappParams(params ZkappSubParams, tps float64) (zkappsToDeploy int, accountQueueSize int) {
	zkappsToDeploy, accountQueueSize = params.ZkappsToDeploy, params.AccountQueueSize
	if zkappsToDeploy == 0 {
		tpsGap := tpsGap(tps, params.Gap)
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
	successfulNodes := make([]NodeAddress, 0, len(nodes))
	remTps := params.Tps
	remFeePayers := params.FeePayers
	var err error
	for nodeIx, nodeAddress := range nodes {
		feePayers := remFeePayers[:feePayersPerNode]
		var handle string
		handle, err = scheduleZkappCommandsDo(config, params, nodeAddress, len(successfulNodes), tps, feePayers)
		if err != nil {
			config.Log.Warnf("error scheduling zkapp txs for %s: %v", nodeAddress, err)
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
		output(ScheduledZkappCommandsReceipt{
			Address: nodeAddress,
			Handle:  handle,
		})
	}
	if err != nil {
		// last schedule payment request didn't work well
		for _, nodeAddress := range successfulNodes {
			handle, err2 := scheduleZkappCommandsDo(config, params, nodeAddress, len(successfulNodes), tps, remFeePayers)
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
