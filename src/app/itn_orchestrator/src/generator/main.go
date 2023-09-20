package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	lib "itn_orchestrator"
)

func fund(p lib.FundParams) lib.GeneratedCommand {
	return lib.GeneratedCommand{Action: lib.FundAction{}.Name(), Params: p}
}

func checkRatio(ratio float64, msg string) {
	if ratio < 0.0 || ratio > 1.0 {
		fmt.Fprintln(os.Stderr, msg)
		os.Exit(2)
	}
}

const mixMaxCostTpsRatioHelp = "when provided, specifies ratio of tps (proportional to total tps) for max cost transactions to be used every other round, zkapps ratio for these rounds is set to 100%"

func main() {
	var rotateKeys, rotateServers string
	var mode string
	var p lib.GenParams
	flag.Float64Var(&p.BaseTps, "base-tps", 0.3, "Base tps rate for the whole network")
	flag.Float64Var(&p.StressTps, "stress-tps", 1, "stress tps rate for the whole network")
	flag.Float64Var(&p.MinTps, "min-tps", 0.01, "minimal tps per node")
	flag.Float64Var(&p.MinStopRatio, "stop-min-ratio", 0.0, "float in range [0..1], minimum ratio of nodes to stop at an interval")
	flag.Float64Var(&p.MaxStopRatio, "stop-max-ratio", 0.5, "float in range [0..1], maximum ratio of nodes to stop at an interval")
	flag.Float64Var(&p.SenderRatio, "sender-ratio", 0.5, "float in range [0..1], max proportion of nodes selected for transaction sending")
	flag.Float64Var(&p.ZkappRatio, "zkapp-ratio", 0.5, "float in range [0..1], ratio of zkapp transactions of all transactions generated")
	flag.Float64Var(&p.StopCleanRatio, "stop-clean-ratio", 0.1, "float in range [0..1], ratio of stops with cleaning of all stops")
	flag.Float64Var(&p.NewAccountRatio, "new-account-ratio", 0, "float in range [0..1], ratio of new accounts, in relation to expected number of zkapp txs, ignored for max-cost txs")
	flag.BoolVar(&p.SendFromNonBpsOnly, "send-from-non-bps", false, "send only from non block producers")
	flag.BoolVar(&p.StopOnlyBps, "stop-only-bps", false, "stop only block producers")
	flag.BoolVar(&p.UseRestartScript, "use-restart-script", false, "use restart script insteadt of stop-daemon command")
	flag.BoolVar(&p.MaxCost, "max-cost", false, "send max-cost zkapp commands")
	flag.IntVar(&p.RoundDurationMin, "round-duration", 30, "duration of a round, minutes")
	flag.IntVar(&p.PauseMin, "pause", 15, "duration of a pause between rounds, minutes")
	flag.IntVar(&p.Rounds, "rounds", 4, "number of rounds to run experiment")
	flag.IntVar(&p.StopsPerRound, "round-stops", 2, "number of stops to perform within round")
	flag.IntVar(&p.Gap, "gap", 180, "gap between related transactions, seconds")
	flag.StringVar(&mode, "mode", "default", "mode of generation")
	flag.StringVar(&p.FundKeyPrefix, "fund-keys-dir", "./fund-keys", "Dir for generated fund key prefixes")
	flag.StringVar(&p.PasswordEnv, "password-env", "", "Name of environment variable to read privkey password from")
	flag.StringVar((*string)(&p.PaymentReceiver), "payment-receiver", "", "Mina PK receiving payments")
	flag.StringVar(&p.ExperimentName, "experiment-name", "exp-0", "Name of experiment")
	flag.IntVar(&p.PrivkeysPerFundCmd, "privkeys-per-fund", 1, "Number of private keys to use per fund command")
	flag.IntVar(&p.GenerateFundKeys, "generate-privkeys", 0, "Number of funding keys to generate from the private key")
	flag.StringVar(&rotateKeys, "rotate-keys", "", "Comma-separated list of public keys to rotate")
	flag.StringVar(&rotateServers, "rotate-servers", "", "Comma-separated list of servers for rotation")
	flag.Float64Var(&p.RotationRatio, "rotate-ratio", 0.3, "Ratio of balance to rotate")
	flag.BoolVar(&p.RotationPermutation, "rotate-permutation", false, "Whether to generate only permutation mappings for rotation")
	flag.IntVar(&p.LargePauseMin, "large-pause", 0, "duration of the large pause, minutes")
	flag.IntVar(&p.LargePauseEveryNRounds, "large-pause-every", 8, "number of rounds in between large pauses")
	flag.Float64Var(&p.MixMaxCostTpsRatio, "max-cost-mixed", 0, mixMaxCostTpsRatioHelp)
	flag.Uint64Var(&p.MaxBalanceChange, "max-balance-change", 1e3, "Max balance change for zkapp account update")
	flag.Uint64Var(&p.MinBalanceChange, "min-balance-change", 0, "Min balance change for zkapp account update")
	flag.Uint64Var(&p.DeploymentFee, "deployment-fee", 1e9, "Zkapp deployment fee")
	flag.Uint64Var(&p.FundFee, "fund-fee", 1e9, "Funding tx fee")
	flag.Uint64Var(&p.MinFee, "min-fee", 1e9, "Min tx fee")
	flag.Uint64Var(&p.MaxFee, "max-fee", 2e9, "Max tx fee")
	flag.Uint64Var(&p.PaymentAmount, "payment-amount", 1e5, "Payment amount")
	flag.Parse()
	checkRatio(p.SenderRatio, "wrong sender ratio")
	checkRatio(p.ZkappRatio, "wrong zkapp ratio")
	checkRatio(p.MinStopRatio, "wrong min stop ratio")
	checkRatio(p.MaxStopRatio, "wrong max stop ratio")
	checkRatio(p.StopCleanRatio, "wrong stop-clean ratio")
	checkRatio(p.MixMaxCostTpsRatio, "wrong max-cost-mixed ratio")
	if p.MaxCost && p.MixMaxCostTpsRatio > 1e-3 {
		fmt.Fprintln(os.Stderr, "both max-cost-mixed and max-cost specified")
		os.Exit(2)
	}
	if p.LargePauseEveryNRounds <= 0 {
		fmt.Fprintln(os.Stderr, "wrong large-pause-every: should be a positive number")
		os.Exit(2)
	}
	if p.RoundDurationMin*60 < p.Gap*4 {
		fmt.Fprintln(os.Stderr, "increase round duration: roundDurationMin*60 should be more than gap*4")
		os.Exit(9)
	}
	if p.NewAccountRatio < 0 {
		fmt.Fprintln(os.Stderr, "wrong new account ratio")
		os.Exit(2)
	}
	checkRatio(p.RotationRatio, "wrong rotation ratio")
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
	if rotateKeys != "" {
		p.RotationKeys = strings.Split(rotateKeys, ",")
	}
	if rotateServers != "" {
		p.RotationServers = strings.Split(rotateServers, ",")
	}
	if len(p.RotationServers) != len(p.RotationKeys) {
		fmt.Fprintln(os.Stderr, "wrong rotation configuration")
		os.Exit(5)
	}
	switch mode {
	case "stop-ratio-distribution":
		for i := 0; i < 10000; i++ {
			v := lib.SampleStopRatio(p.MinStopRatio, p.MaxStopRatio)
			fmt.Println(v)
		}
		return
	case "tps-distribution":
		for i := 0; i < 10000; i++ {
			v := lib.SampleTps(p.BaseTps, p.StressTps)
			fmt.Println(v)
		}
		return
	case "default":
	default:
		os.Exit(1)
	}
	if p.PaymentReceiver == "" && p.ZkappRatio < 0.999 {
		fmt.Fprintln(os.Stderr, "Payment receiver not specified")
		os.Exit(2)
	}
	encoder := json.NewEncoder(os.Stdout)
	writeComment := func(comment string) {
		if err := encoder.Encode(comment); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing comment: %v\n", err)
			os.Exit(3)
		}
	}
	writeComment("Generated with: " + strings.Join(os.Args, " "))
	writeComment("Funding keys for the experiment")
	writeCommand := func(cmd lib.GeneratedCommand) {
		comment := cmd.Comment()
		if comment != "" {
			writeComment(comment)
		}
		if err := encoder.Encode(cmd); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing command: %v\n", err)
			os.Exit(3)
		}
	}
	cmds := []lib.GeneratedCommand{}
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
			Fee:         p.FundFee,
			Num:         p.GenerateFundKeys,
		}))
		writeCommand(lib.GenWait(1))
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
