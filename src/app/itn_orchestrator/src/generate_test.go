package itn_orchestrator

import (
	"math/rand"
	"testing"
)

func someParams() GenParams {
	return GenParams{
		MinTps:                 0.01,
		BaseTps:                0.6,
		StressTps:              1.4,
		SenderRatio:            0.8,
		ZkappRatio:             0.7,
		NewAccountRatio:        1.5,
		StopCleanRatio:         0.5,
		MinStopRatio:           0.1,
		MaxStopRatio:           0.25,
		RoundDurationMin:       50,
		PauseMin:               10,
		Rounds:                 48,
		StopsPerRound:          1,
		Gap:                    100,
		ExperimentName:         "test",
		Privkeys:               []string{"key0"},
		PaymentReceiver:        "B62qpPita1s7Dbnr7MVb3UK8fdssZixL1a4536aeMYxbTJEtRGGyS8U",
		PrivkeysPerFundCmd:     2,
		GenerateFundKeys:       20,
		MixMaxCostTpsRatio:     0.7,
		LargePauseEveryNRounds: 8,
		LargePauseMin:          240,
		MinBalanceChange:       1e3,
		MaxBalanceChange:       3e3,
		DeploymentFee:          1e9,
		PaymentAmount:          1e5,
		MinFee:                 1e9,
		MaxFee:                 3e9,
		FundFee:                1e9,
	}
}

type shuffledIxs []int

func (ixs *shuffledIxs) Push(ix int) {
	*ixs = append(*ixs, ix)
}

func (ixs *shuffledIxs) Pop() int {
	l := len(*ixs)
	if l == 0 {
		panic("unexpected pop")
	}
	i := rand.Intn(l)
	res := (*ixs)[i]
	(*ixs)[i] = (*ixs)[l-1]
	*ixs = (*ixs)[:l-1]
	return res
}

type zkappGenState struct {
	balances          []int64
	availableDeployed shuffledIxs
	availableNew      shuffledIxs
	queue             []int
	numNewAccounts    int
	conf              ZkappCommandsDetails
}

func newZkappGenState(pi ZkappCommandsDetails, numFeePayers int, balances []int64) zkappGenState {
	availableDeployed := rand.Perm(pi.NumZkappsToDeploy)
	for i := range availableDeployed {
		availableDeployed[i] += numFeePayers
	}
	return zkappGenState{
		numNewAccounts:    pi.NumNewAccounts,
		balances:          balances,
		availableDeployed: availableDeployed,
		conf:              pi,
	}
}

func (state *zkappGenState) applyTx(numFeePayers, feePayerIx, accountUpdates, newAccounts, zkappAccounts int) {
	state.numNewAccounts -= newAccounts
	state.balances[feePayerIx] -= int64(state.conf.MaxFee)
	availableDeployed := len(state.availableDeployed)
	availableNew := len(state.availableNew)
	tot := availableDeployed + availableNew
	if tot <= 0 {
		panic("not enough keys")
	}
	// TODO popped should be reused
	popped := make([]int, 0, accountUpdates-newAccounts)
	poppedCnt := make([]int, accountUpdates-newAccounts+1)
	numNewPops := 0
	for i := 0; i < accountUpdates-newAccounts-zkappAccounts; i++ {
		r := rand.Intn(tot)
		if r < len(popped) {
			poppedCnt[r]++
			numNewPops++
		} else if r < availableNew {
			popped = append(popped, state.availableNew.Pop())
			numNewPops++
		}
	}
	numDeployedToPop := accountUpdates - newAccounts - numNewPops + 1
	newActuallyPopped := len(popped)
	for i := 0; i < numDeployedToPop; i++ {
		r := rand.Intn(availableDeployed) + newActuallyPopped
		if r < len(popped) {
			poppedCnt[r]++
		} else {
			popped = append(popped, state.availableDeployed.Pop())
		}
	}
	balancing := popped[len(popped)-1]
	poppedCnt[len(popped)-1]--
	state.queue = append(state.queue, popped...)
	for i := 0; i < newAccounts; i++ {
		ix := len(state.balances)
		state.balances = append(state.balances, int64(state.conf.MinNewZkappBalance)-1e9)
		state.queue = append(state.queue, ix)
	}
	if len(state.queue) > state.conf.AccountQueueSize {
		prefix := len(state.queue) - state.conf.AccountQueueSize
		for _, ix := range state.queue[:prefix] {
			if ix < numFeePayers+state.conf.NumZkappsToDeploy {
				state.availableDeployed.Push(ix)
			} else {
				state.availableNew.Push(ix)
			}
		}
		state.queue = state.queue[prefix:]
	}
	for i, ix := range popped {
		state.balances[ix] -= int64(state.conf.MaxBalanceChange*2) * int64(poppedCnt[i]+1)
	}
	state.balances[balancing] -= int64(accountUpdates*2-newAccounts)*int64(state.conf.MaxBalanceChange) + int64(newAccounts)*int64(state.conf.MaxNewZkappBalance)
}

func testZkapp(t *testing.T, numFeePayers int, feePayerBalance int64, pi ZkappCommandsDetails) {
	balances := make([]int64, numFeePayers+pi.NumZkappsToDeploy)
	for i := 0; i < numFeePayers; i++ {
		balances[i] = feePayerBalance
	}
	for j := 0; j < pi.NumZkappsToDeploy; j++ {
		balances[j%numFeePayers] -= int64(pi.DeploymentFee + pi.InitBalance)
		balances[numFeePayers+j] = int64(pi.InitBalance) - 1e9
	}
	numTxs := int(float64(pi.DurationMin*60) * pi.Tps)
	if pi.MaxCost {
		for j := pi.NumZkappsToDeploy; j < numTxs; j++ {
			balances[j%numFeePayers] -= int64(pi.MaxFee)
		}
	} else {
		state := newZkappGenState(pi, numFeePayers, balances)
		for j := pi.NumZkappsToDeploy; j < numTxs; j++ {
			accUpdates := rand.Intn(pi.MaxAccountUpdates) + 1
			newAccs := 0
			if state.numNewAccounts > 0 {
				newAccs = rand.Intn(accUpdates + 1)
			}
			zkappAccs := 0
			for k := 0; k < accUpdates-newAccs; k++ {
				if rand.Intn(3) == 0 {
					zkappAccs++
				}
			}
			// t.Logf("%d:%d (%d new)", accUpdates*2+2, zkappAccs, newAccs)
			state.applyTx(numFeePayers, j%numFeePayers, accUpdates, newAccs, zkappAccs)
		}
		balances = state.balances
	}
	for ix, b := range balances {
		type_ := "new"
		if ix < numFeePayers {
			type_ = "fee payer"
		} else if ix < numFeePayers+pi.NumZkappsToDeploy {
			type_ = "zkapp"
		}
		if b < 0 {
			t.Errorf("balance underflow %d for %s account", b, type_)
		}
	}
	if t.Failed() {
		t.Logf("Fee payer balance: %d", feePayerBalance)
		t.Logf("Init zkapp balance: %d", pi.InitBalance)
		t.Logf("New account balance: %d", pi.MaxNewZkappBalance)
	}
}

func testPayment(t *testing.T, numFeePayers int, feePayerBalance int64, pi PaymentsDetails) {
	balances := make([]int64, numFeePayers)
	for i := 0; i < numFeePayers; i++ {
		balances[i] = feePayerBalance
	}
	numTxs := int(float64(pi.DurationMin*60) * pi.Tps)
	for i := 0; i < numTxs; i++ {
		balances[i%numFeePayers] -= int64(pi.Amount + pi.MaxFee)
	}
	for _, b := range balances {
		if b < 0 {
			t.Errorf("balance underflow %d for fee payer", b)
		}
	}
	if t.Failed() {
		t.Logf("Fee payer balance: %d", feePayerBalance)
	}
}

func TestGenerate(t *testing.T) {
	for i := 0; i < 100; i++ {
		params := someParams()
		for r := 0; r < params.Rounds; r++ {
			round := params.Generate(r)
			var zkappParams *ZkappSubParams
			var paymentParams *PaymentSubParams
			for _, c := range round.Commands {
				if c.Action == (ZkappCommandsAction{}).Name() {
					p := (c.Params.(ZkappRefParams).ZkappSubParams)
					zkappParams = &p
				} else if c.Action == (PaymentsAction{}).Name() {
					p := (c.Params.(PaymentRefParams).PaymentSubParams)
					paymentParams = &p
				}
			}
			if zkappParams != nil {
				fund := *round.ZkappFundCommand
				participants := int(zkappParams.Tps / zkappParams.MinTps)
				tpsPerNode := zkappParams.Tps / float64(participants)
				pi := ZkappPaymentsInput(*zkappParams, 0, tpsPerNode)
				numFeePayers := fund.Num / participants
				feePayerBalance := int64(fund.Amount) / int64(fund.Num)
				for j := 0; j < 1000; j++ {
					testZkapp(t, numFeePayers, feePayerBalance, pi)
				}
			}
			if paymentParams != nil {
				fund := *round.PaymentFundCommand
				participants := int(paymentParams.Tps / paymentParams.MinTps)
				tpsPerNode := paymentParams.Tps / float64(participants)
				numFeePayers := fund.Num / participants
				feePayerBalance := int64(fund.Amount) / int64(fund.Num)
				pi := paymentInput(*paymentParams, 0, tpsPerNode)
				for j := 0; j < 1000; j++ {
					testPayment(t, numFeePayers, feePayerBalance, pi)
				}
			}
		}
	}
}
