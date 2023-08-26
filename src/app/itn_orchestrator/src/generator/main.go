package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"itn_json_types"
	"math"
	"math/rand"
	"os"
	"sort"

	lib "itn_orchestrator"
)

/*
 * Returns random number in normal distribution centering on 0.
 * ~95% of numbers returned should fall between -2 and 2
 * ie within two standard deviations
 */
func gaussRandom() float64 {
	u := 2*rand.Float64() - 1
	v := 2*rand.Float64() - 1
	r := u*u + v*v
	// if outside interval [0,1] start over
	if r == 0 || r >= 1 {
		return gaussRandom()
	}

	c := math.Sqrt(-2 * math.Log(r) / r)
	return u * c
}

func sampleTps(baseTps, stressTps float64) float64 {
	tpsStddev := (stressTps - baseTps) / 2
	return tpsStddev*math.Abs(gaussRandom()) + baseTps
}

func sampleStopRatio(minRatio, maxRatio float64) float64 {
	stddev := (maxRatio - minRatio) / 3
	return stddev*math.Abs(gaussRandom()) + minRatio
}

type Params struct {
	BaseTps, StressTps, SenderRatio, ZkappRatio, RedeployRatio, MinStopRatio, MaxStopRatio float64
	RoundDurationMin, PauseMin, Rounds, StopsPerRound, Gap                                 int
	SendFromNonBpsOnly, StopOnlyBps, UseRestartScript, MaxCost                             bool
	ExperimentName, PasswordEnv, FundKeyPrefix                                             string
	Privkeys                                                                               []string
	PaymentReceiver                                                                        itn_json_types.MinaPublicKey
	PrivkeysPerFundCmd                                                                     int
	GenerateFundKeys                                                                       int
}

type Command struct {
	Action  string `json:"action"`
	Params  any    `json:"params"`
	comment string
}

type GeneratedRound struct {
	Commands     []Command
	FundCommands []lib.FundParams
}

func fund(p lib.FundParams) Command {
	return Command{Action: lib.FundAction{}.Name(), Params: p}
}

func loadKeys(p lib.KeyloaderParams) Command {
	return Command{Action: lib.KeyloaderAction{}.Name(), Params: p}
}

func discovery(p lib.DiscoveryParams) Command {
	return Command{Action: lib.DiscoveryAction{}.Name(), Params: p}
}

type SampleRefParams struct {
	Group  lib.ComplexValue `json:"group"`
	Ratios []float64        `json:"ratios"`
}

func sample(groupRef int, groupName string, ratios []float64) Command {
	return Command{Action: lib.SampleAction{}.Name(), Params: SampleRefParams{
		Group:  lib.LocalComplexValue(groupRef, groupName),
		Ratios: ratios,
	}}
}

type ZkappRefParams struct {
	lib.ZkappSubParams
	FeePayers lib.ComplexValue `json:"feePayers"`
	Nodes     lib.ComplexValue `json:"nodes"`
}

func zkapps(feePayersRef int, nodesRef int, nodesName string, params lib.ZkappSubParams) Command {
	return Command{Action: lib.ZkappCommandsAction{}.Name(), Params: ZkappRefParams{
		ZkappSubParams: params,
		FeePayers:      lib.LocalComplexValue(feePayersRef, "key"),
		Nodes:          lib.LocalComplexValue(nodesRef, nodesName),
	}}
}

type PaymentRefParams struct {
	lib.PaymentSubParams
	FeePayers lib.ComplexValue `json:"feePayers"`
	Nodes     lib.ComplexValue `json:"nodes"`
}

func payments(feePayersRef int, nodesRef int, nodesName string, params lib.PaymentSubParams) Command {
	return Command{Action: lib.PaymentsAction{}.Name(), Params: PaymentRefParams{
		PaymentSubParams: params,
		FeePayers:        lib.LocalComplexValue(feePayersRef, "key"),
		Nodes:            lib.LocalComplexValue(nodesRef, nodesName),
	}}
}

func wait(sec int) Command {
	return Command{Action: lib.WaitAction{}.Name(), Params: lib.WaitParams{
		Seconds: sec,
	}}
}

type RestartRefParams struct {
	Nodes lib.ComplexValue `json:"nodes"`
	Clean bool             `json:"clean,omitempty"`
}

func restart(useRestartScript bool, nodesRef int, nodesName string, clean bool) Command {
	var name string
	if useRestartScript {
		name = lib.RestartAction{}.Name()
	} else {
		name = lib.StopDaemonAction{}.Name()
	}
	return Command{Action: name, Params: RestartRefParams{
		Nodes: lib.LocalComplexValue(nodesRef, nodesName),
		Clean: clean,
	}}
}

type JoinRefParams struct {
	Group1 lib.ComplexValue `json:"group1"`
	Group2 lib.ComplexValue `json:"group2"`
}

func join(g1Ref int, g1Name string, g2Ref int, g2Name string) Command {
	return Command{Action: lib.JoinAction{}.Name(), Params: JoinRefParams{
		Group1: lib.LocalComplexValue(g1Ref, g1Name),
		Group2: lib.LocalComplexValue(g2Ref, g2Name),
	}}
}

type ExceptRefParams struct {
	Group  lib.ComplexValue `json:"group"`
	Except lib.ComplexValue `json:"except"`
}

func except(groupRef int, groupName string, exceptRef int, exceptName string) Command {
	return Command{Action: lib.ExceptAction{}.Name(), Params: ExceptRefParams{
		Group:  lib.LocalComplexValue(groupRef, groupName),
		Except: lib.LocalComplexValue(exceptRef, exceptName),
	}}
}

func withComment(comment string, cmd Command) Command {
	cmd.comment = comment
	return cmd
}

func (p *Params) Generate(round int) GeneratedRound {
	zkappsKeysDir := fmt.Sprintf("%s/round-%d/zkapps", p.FundKeyPrefix, round)
	paymentsKeysDir := fmt.Sprintf("%s/round-%d/payments", p.FundKeyPrefix, round)
	tps := sampleTps(p.BaseTps, p.StressTps)
	experimentName := fmt.Sprintf("%s-%d", p.ExperimentName, round)
	onlyZkapps := math.Abs(1-p.ZkappRatio) < 1e-3
	onlyPayments := p.ZkappRatio < 1e-3
	zkappTps := tps * p.ZkappRatio
	zkappParams := lib.ZkappSubParams{
		ExperimentName:    experimentName,
		Tps:               zkappTps,
		MinTps:            0.01,
		DurationInMinutes: p.RoundDurationMin,
		Gap:               p.Gap,
		MinBalanceChange:  0,
		MaxBalanceChange:  1e5,
		MinFee:            2e9,
		MaxFee:            4e9,
		DeploymentFee:     2e9,
		MaxCost:           p.MaxCost,
	}
	paymentParams := lib.PaymentSubParams{
		ExperimentName: experimentName,
		Tps:            tps - zkappTps,
		MinTps:         0.02,
		DurationMin:    p.RoundDurationMin,
		MinFee:         1e9,
		MaxFee:         2e9,
		Amount:         1e5,
		Receiver:       p.PaymentReceiver,
	}
	cmds := []Command{}
	roundStartMin := round * (p.RoundDurationMin + p.PauseMin)
	cmds = append(cmds, withComment(fmt.Sprintf("Starting round %d, %d min since start", round, roundStartMin), discovery(lib.DiscoveryParams{
		OffsetMin:        15,
		NoBlockProducers: p.SendFromNonBpsOnly,
	})))
	sendersOutName := "participant"
	if 1-p.SenderRatio > 1e-6 {
		sendersOutName = "group1"
		cmds = append(cmds, sample(-1, "participant", []float64{p.SenderRatio}))
	}
	if onlyPayments {
		cmds = append(cmds, loadKeys(lib.KeyloaderParams{Dir: paymentsKeysDir}))
		cmds = append(cmds, payments(-1, -2, sendersOutName, paymentParams))
	} else if onlyZkapps {
		cmds = append(cmds, loadKeys(lib.KeyloaderParams{Dir: zkappsKeysDir}))
		cmds = append(cmds, zkapps(-1, -2, sendersOutName, zkappParams))
	} else {
		cmds = append(cmds, loadKeys(lib.KeyloaderParams{Dir: zkappsKeysDir}))
		cmds = append(cmds, loadKeys(lib.KeyloaderParams{Dir: paymentsKeysDir}))
		cmds = append(cmds, zkapps(-2, -3, sendersOutName, zkappParams))
		cmds = append(cmds, payments(-2, -4, sendersOutName, paymentParams))
		cmds = append(cmds, join(-1, "participant", -2, "participant"))
	}
	sendersCmdId := len(cmds)
	stopWaits := make([]int, p.StopsPerRound)
	for i := 0; i < p.StopsPerRound; i++ {
		stopWaits[i] = rand.Intn(60 * p.RoundDurationMin)
	}
	sort.Ints(stopWaits)
	for i := p.StopsPerRound - 1; i > 0; i-- {
		stopWaits[i] -= stopWaits[i-1]
	}
	stopRatio := sampleStopRatio(p.MinStopRatio, p.MaxStopRatio)
	elapsed := 0
	for _, waitSec := range stopWaits {
		cmds = append(cmds, withComment(fmt.Sprintf("Running round %d, %d min %d sec since start, waiting for %d sec", round, roundStartMin+elapsed/60, elapsed%60, waitSec), wait(waitSec)))
		cmds = append(cmds, discovery(lib.DiscoveryParams{
			OffsetMin:          15,
			OnlyBlockProducers: p.StopOnlyBps,
		}))
		exceptRefName := "group"
		if onlyPayments || onlyZkapps {
			exceptRefName = "participant"
		}
		cmds = append(cmds, except(-1, "participant", sendersCmdId-len(cmds)-1, exceptRefName))
		redeployRatio := p.RedeployRatio * stopRatio
		restartRatio := (1 - p.RedeployRatio) * stopRatio
		if redeployRatio > 1e-6 && restartRatio > 1e-6 {
			cmds = append(cmds, sample(-1, "group", []float64{redeployRatio, restartRatio}))
			cmds = append(cmds, restart(p.UseRestartScript, -1, "group1", true))
			cmds = append(cmds, restart(p.UseRestartScript, -2, "group2", false))
		} else if redeployRatio > 1e-6 {
			cmds = append(cmds, sample(-1, "group", []float64{redeployRatio}))
			cmds = append(cmds, restart(p.UseRestartScript, -1, "group1", true))
		} else if restartRatio > 1e-6 {
			cmds = append(cmds, sample(-1, "group", []float64{restartRatio}))
			cmds = append(cmds, restart(p.UseRestartScript, -1, "group1", false))
		}
		elapsed += waitSec
	}
	if round < p.Rounds-1 {
		cmds = append(cmds,
			withComment(fmt.Sprintf("Waiting for remainder of round %d and pause, %d min %d sec since start", round, roundStartMin+elapsed/60, elapsed%60),
				wait((p.RoundDurationMin+p.PauseMin)*60-elapsed)))
	}
	fundCmds := []lib.FundParams{}
	if !onlyPayments {
		zkappKeysNum, zkappAmount := lib.ZkappKeygenRequirements(zkappParams)
		fundCmds = append(fundCmds,
			lib.FundParams{
				PasswordEnv: p.PasswordEnv,
				Prefix:      zkappsKeysDir + "/key",
				Amount:      zkappAmount,
				Fee:         1e9,
				Num:         zkappKeysNum,
			})
	}
	if !onlyZkapps {
		paymentKeysNum, paymentAmount := lib.PaymentKeygenRequirements(p.Gap, paymentParams)
		fundCmds = append(fundCmds,
			lib.FundParams{
				PasswordEnv: p.PasswordEnv,
				// Privkeys:    privkeys,
				Prefix: paymentsKeysDir + "/key",
				Amount: paymentAmount,
				Fee:    1e9,
				Num:    paymentKeysNum,
			})
	}
	return GeneratedRound{
		Commands:     cmds,
		FundCommands: fundCmds,
	}
}

func checkRatio(ratio float64, msg string) {
	if ratio < 0.0 || ratio > 1.0 {
		fmt.Fprintln(os.Stderr, msg)
		os.Exit(2)
	}
}

func main() {
	var mode string
	var p Params
	flag.Float64Var(&p.BaseTps, "base-tps", 0.3, "Base tps rate for the whole network")
	flag.Float64Var(&p.StressTps, "stress-tps", 1, "stress tps rate for the whole network")
	flag.Float64Var(&p.MinStopRatio, "stop-min-ratio", 0.0, "float in range [0..1], minimum ratio of nodes to stop at an interval")
	flag.Float64Var(&p.MaxStopRatio, "stop-max-ratio", 0.5, "float in range [0..1], maximum ratio of nodes to stop at an interval")
	flag.Float64Var(&p.SenderRatio, "sender-ratio", 0.5, "float in range [0..1], max proportion of nodes selected for transaction sending")
	flag.Float64Var(&p.ZkappRatio, "zkapp-ratio", 0.5, "float in range [0..1], ratio of zkapp transactions of all transactions generated")
	flag.Float64Var(&p.RedeployRatio, "redeploy-ratio", 0.1, "float in range [0..1], ratio of redeploys of all node stops")
	flag.BoolVar(&p.SendFromNonBpsOnly, "send-from-non-bps", false, "send only from non block producers")
	flag.BoolVar(&p.StopOnlyBps, "stop-only-bps", false, "stop only block producers")
	flag.BoolVar(&p.UseRestartScript, "use-restart-script", false, "use restart script insteadt of stop-daemon command")
	flag.BoolVar(&p.MaxCost, "max-cost", false, "send max-cost zkapp commands")
	flag.IntVar(&p.RoundDurationMin, "round-duration", 30, "duration of a round, minutes")
	flag.IntVar(&p.PauseMin, "pause", 15, "duration of a pause between rounds, minutes")
	flag.IntVar(&p.Rounds, "rounds", 4, "number of rounds to run experiment")
	flag.IntVar(&p.StopsPerRound, "round-stops", 2, "number of stops to perform within round")
	flag.IntVar(&p.Gap, "gap", 180, "gap between related transactions, seconds")
	checkRatio(p.SenderRatio, "wrong sender ratio")
	checkRatio(p.ZkappRatio, "wrong zkapp ratio")
	checkRatio(p.MinStopRatio, "wrong min stop ratio")
	checkRatio(p.MaxStopRatio, "wrong max stop ratio")
	checkRatio(p.RedeployRatio, "wrong redeploy ratio")
	flag.StringVar(&mode, "mode", "default", "mode of generation")
	flag.StringVar(&p.FundKeyPrefix, "fund-keys-dir", "./fund-keys", "Dir for generated fund key prefixes")
	flag.StringVar(&p.PasswordEnv, "password-env", "", "Name of environment variable to read privkey password from")
	flag.StringVar((*string)(&p.PaymentReceiver), "payment-receiver", "", "Mina PK receiving payments")
	flag.StringVar(&p.ExperimentName, "experiment-name", "exp-0", "Name of experiment")
	flag.IntVar(&p.PrivkeysPerFundCmd, "privkeys-per-fund", 1, "Number of private keys to use per fund command")
	flag.IntVar(&p.GenerateFundKeys, "generate-privkeys", 0, "Number of funding keys to generate from the private key")
	flag.Parse()
	p.Privkeys = flag.Args()
	if len(p.Privkeys) == 0 {
		fmt.Fprintln(os.Stderr, "Specify funding private key files after all flags (separated by spaces)")
		os.Exit(4)
	}
	if p.GenerateFundKeys > 0 && len(p.Privkeys) > 1 {
		fmt.Fprintln(os.Stderr, "When option -generate-funding-keys is used, only a single private key should be provided")
		os.Exit(4)
	}
	if (p.GenerateFundKeys > 0 && p.GenerateFundKeys < p.PrivkeysPerFundCmd) || (p.GenerateFundKeys == 0 && len(p.Privkeys) < p.PrivkeysPerFundCmd) {
		fmt.Fprintln(os.Stderr, "Number of private keys is less than -privkeys-per-fund")
		os.Exit(4)
	}
	switch mode {
	case "stop-ratio-distribution":
		for i := 0; i < 10000; i++ {
			v := sampleStopRatio(p.MinStopRatio, p.MaxStopRatio)
			fmt.Println(v)
		}
		return
	case "tps-distribution":
		for i := 0; i < 10000; i++ {
			v := sampleTps(p.BaseTps, p.StressTps)
			fmt.Println(v)
		}
		return
	case "default":
	default:
		os.Exit(1)
	}
	if p.PaymentReceiver == "" {
		fmt.Fprintln(os.Stderr, "Payment receiver not specified")
		os.Exit(2)
	}
	encoder := json.NewEncoder(os.Stdout)
	_ = encoder.Encode("Funding keys for the experiment")
	writeCommand := func(cmd Command) {
		if cmd.comment != "" {
			if err := encoder.Encode(cmd.comment); err != nil {
				fmt.Fprintf(os.Stderr, "Error writing comment: %v\n", err)
				os.Exit(3)
			}
		}
		if err := encoder.Encode(cmd); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing command: %v\n", err)
			os.Exit(3)
		}
	}
	cmds := []Command{}
	fundCmds := []lib.FundParams{}
	for r := 0; r < p.Rounds; r++ {
		round := p.Generate(r)
		cmds = append(cmds, round.Commands...)
		fundCmds = append(fundCmds, round.FundCommands...)
	}
	privkeys := p.Privkeys
	if p.GenerateFundKeys > 0 {
		fundKeysDir := fmt.Sprintf("%s/funding", p.FundKeyPrefix)
		privkeys = make([]string, p.GenerateFundKeys)
		privkeyAmounts := make([]uint64, p.GenerateFundKeys)
		for i := range privkeys {
			privkeys[i] = fmt.Sprintf("%s/key-0-%d", fundKeysDir, i)
		}
		for i, f := range fundCmds {
			i_ := (i * p.PrivkeysPerFundCmd) % p.GenerateFundKeys
			itemsPerFundKey := f.Num/p.PrivkeysPerFundCmd + 1
			perGeneratedKey := f.Amount / uint64(f.Num) * uint64(itemsPerFundKey)
			for j := i_; j < (i_ + p.PrivkeysPerFundCmd); j++ {
				j_ := j % p.GenerateFundKeys
				privkeyAmounts[j_] += perGeneratedKey
			}
		}
		perKeyAmount := privkeyAmounts[0]
		for _, a := range privkeyAmounts[1:] {
			if perKeyAmount < a {
				perKeyAmount = a
			}
		}
		// Generate funding keys
		writeCommand(fund(lib.FundParams{
			PasswordEnv: p.PasswordEnv,
			Privkeys:    p.Privkeys,
			Prefix:      fundKeysDir + "/key",
			Amount:      perKeyAmount*uint64(p.GenerateFundKeys)*3/2 + 2e9,
			Fee:         1e9,
			Num:         p.GenerateFundKeys,
		}))
		writeCommand(wait(1))
	}
	privkeysExt := append(privkeys, privkeys...)
	for i, cmd := range fundCmds {
		i_ := (i * p.PrivkeysPerFundCmd) % len(privkeys)
		cmd.Privkeys = privkeysExt[i_:(i_ + p.PrivkeysPerFundCmd)]
		writeCommand(fund(cmd))
	}
	for _, cmd := range cmds {
		writeCommand(cmd)
	}
}
