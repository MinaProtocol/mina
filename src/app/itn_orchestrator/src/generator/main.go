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
	"strings"

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
	SendFromNonBpsOnly, StopOnlyBps                                                        bool
	ExperimentName, PasswordEnv, FundKeyPrefix                                             string
	Privkeys                                                                               []string
	PaymentReceiver                                                                        itn_json_types.MinaPublicKey
}

type Command struct {
	Action  string
	Params  any
	comment string
}

type GeneratedRound struct {
	Commands     []Command
	FundCommands []Command
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
	Group  lib.ComplexValue
	Ratios []float64
}

func sample(groupRef int, groupName string, ratios []float64) Command {
	return Command{Action: lib.SampleAction{}.Name(), Params: SampleRefParams{
		Group:  lib.LocalComplexValue(groupRef, groupName),
		Ratios: ratios,
	}}
}

type ZkappRefParams struct {
	lib.ZkappSubParams
	FeePayers lib.ComplexValue
	Nodes     lib.ComplexValue
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
	Senders lib.ComplexValue
	Nodes   lib.ComplexValue
}

func payments(feePayersRef int, nodesRef int, nodesName string, params lib.PaymentSubParams) Command {
	return Command{Action: lib.PaymentsAction{}.Name(), Params: PaymentRefParams{
		PaymentSubParams: params,
		Senders:          lib.LocalComplexValue(feePayersRef, "key"),
		Nodes:            lib.LocalComplexValue(nodesRef, nodesName),
	}}
}

func wait(sec int) Command {
	return Command{Action: lib.WaitAction{}.Name(), Params: lib.WaitParams{
		Seconds: sec,
	}}
}

type RestartRefParams struct {
	Nodes lib.ComplexValue
	Clean bool
}

func restart(nodesRef int, nodesName string, clean bool) Command {
	return Command{Action: lib.RestartAction{}.Name(), Params: RestartRefParams{
		Nodes: lib.LocalComplexValue(nodesRef, nodesName),
		Clean: clean,
	}}
}

type JoinRefParams struct {
	Group1 lib.ComplexValue
	Group2 lib.ComplexValue
}

func join(g1Ref int, g1Name string, g2Ref int, g2Name string) Command {
	return Command{Action: lib.JoinAction{}.Name(), Params: JoinRefParams{
		Group1: lib.LocalComplexValue(g1Ref, g1Name),
		Group2: lib.LocalComplexValue(g2Ref, g2Name),
	}}
}

type ExceptRefParams struct {
	Group  lib.ComplexValue
	Except lib.ComplexValue
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
	experimentName := fmt.Sprintf("%s (round %d)", p.ExperimentName, round)
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
	}
	zkappKeysNum, zkappAmount := lib.ZkappKeygenRequirements(zkappParams)
	paymentParams := lib.PaymentSubParams{
		ExperimentName:    experimentName,
		Tps:               tps - zkappTps,
		MinTps:            0.02,
		DurationInMinutes: p.RoundDurationMin,
		FeeMin:            1e9,
		FeeMax:            2e9,
		Amount:            1e5,
		Receiver:          p.PaymentReceiver,
	}
	paymentKeysNum, paymentAmount := lib.PaymentKeygenRequirements(p.Gap, paymentParams)
	cmds := []Command{}
	roundStartMin := round * (p.RoundDurationMin + p.PauseMin)
	cmds = append(cmds, withComment(fmt.Sprintf("Starting round %d, %d min since start", round, roundStartMin), discovery(lib.DiscoveryParams{
		OffsetMin:        15,
		NoBlockProducers: p.SendFromNonBpsOnly,
	})))
	cmds = append(cmds, sample(-1, "participant", []float64{p.SenderRatio}))
	cmds = append(cmds, loadKeys(lib.KeyloaderParams{Dir: zkappsKeysDir}))
	cmds = append(cmds, loadKeys(lib.KeyloaderParams{Dir: paymentsKeysDir}))
	cmds = append(cmds, zkapps(-2, -3, "group1", zkappParams))
	cmds = append(cmds, payments(-2, -4, "group1", paymentParams))
	cmds = append(cmds, join(-1, "participant", -2, "participant"))
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
	for i, waitSec := range stopWaits {
		cmds = append(cmds, withComment(fmt.Sprintf("Running round %d, %d min %d sec since start, waiting for %d sec", round, roundStartMin+elapsed/60, elapsed%60, waitSec), wait(waitSec)))
		cmds = append(cmds, discovery(lib.DiscoveryParams{
			OffsetMin:          15,
			OnlyBlockProducers: p.StopOnlyBps,
		}))
		cmds = append(cmds, except(-1, "participant", -3-i*6, "group"))
		cmds = append(cmds, sample(-1, "group", []float64{p.RedeployRatio * stopRatio, (1 - p.RedeployRatio) * stopRatio}))
		cmds = append(cmds, restart(-1, "group1", true))
		cmds = append(cmds, restart(-2, "group2", false))
		elapsed += waitSec
	}
	if round < p.Rounds-1 {
		cmds = append(cmds,
			withComment(fmt.Sprintf("Waiting for remainder of round %d and pause, %d min %d sec since start", round, roundStartMin+elapsed/60, elapsed%60),
				wait((p.RoundDurationMin+p.PauseMin)*60-elapsed)))
	}
	return GeneratedRound{
		Commands: cmds,
		FundCommands: []Command{
			fund(lib.FundParams{
				PasswordEnv: p.PasswordEnv,
				Privkeys:    p.Privkeys,
				Prefix:      zkappsKeysDir + "/key",
				Amount:      zkappAmount,
				Fee:         1e9,
				Num:         zkappKeysNum,
			}),
			fund(lib.FundParams{
				PasswordEnv: p.PasswordEnv,
				Privkeys:    p.Privkeys,
				Prefix:      paymentsKeysDir + "/key-",
				Amount:      paymentAmount,
				Fee:         1e9,
				Num:         paymentKeysNum,
			}),
		},
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
	var privkeys string
	flag.Float64Var(&p.BaseTps, "base-tps", 0.3, "Base tps rate for the whole network")
	flag.Float64Var(&p.StressTps, "stress-tps", 1, "stress tps rate for the whole network")
	flag.Float64Var(&p.MinStopRatio, "stop-min-ratio", 0.0, "float in range [0..1], minimum ratio of nodes to stop at an interval")
	flag.Float64Var(&p.MaxStopRatio, "stop-max-ratio", 0.5, "float in range [0..1], maximum ratio of nodes to stop at an interval")
	flag.Float64Var(&p.SenderRatio, "sender-ratio", 0.5, "float in range [0..1], max proportion of nodes selected for transaction sending")
	flag.Float64Var(&p.ZkappRatio, "zkapp-ratio", 0.5, "float in range [0..1], ratio of zkapp transactions of all transactions generated")
	flag.Float64Var(&p.RedeployRatio, "redeploy-ratio", 0.1, "float in range [0..1], ratio of redeploys of all node stops")
	flag.BoolVar(&p.SendFromNonBpsOnly, "send-from-non-bps", false, "send only from non block producers")
	flag.BoolVar(&p.StopOnlyBps, "stop-only-bps", false, "stop only block producers")
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
	flag.StringVar(&privkeys, "privkey", "", "private key files to use for funding, comma-separated")
	flag.StringVar(&p.FundKeyPrefix, "fund-keys-dir", "./fund-keys", "Dir for generated fund key prefixes")
	flag.StringVar(&p.PasswordEnv, "password-env", "", "Name of environment variable to read privkey password from")
	flag.StringVar((*string)(&p.PaymentReceiver), "payment-receiver", "", "Mina PK receiving payments")
	flag.Parse()
	p.Privkeys = strings.Split(privkeys, ",")
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
	for r := 0; r < p.Rounds; r++ {
		round := p.Generate(r)
		cmds = append(cmds, round.Commands...)
		for _, cmd := range round.FundCommands {
			writeCommand(cmd)
		}
	}
	for _, cmd := range cmds {
		writeCommand(cmd)
	}
}
