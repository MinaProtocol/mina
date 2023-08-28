package itn_orchestrator

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"sync"
	"time"
)

type FundParams struct {
	Amount      uint64   `json:"amount"`
	Fee         uint64   `json:"fee"`
	Prefix      string   `json:"prefix"`
	Num         int      `json:"num"`
	Privkeys    []string `json:"privkeys"`
	PasswordEnv string   `json:"passwordEnv,omitempty"`
}

type FundAction struct{}

func launchMultiple(ctx context.Context, perform func(ctx context.Context, spawnAction func(func() error))) error {
	var wg sync.WaitGroup
	errs := make(chan error)
	ctx, cancelF := context.WithCancel(ctx)
	defer cancelF()
	perform(ctx, func(run func() error) {
		wg.Add(1)
		go func() {
			if err := run(); err != nil {
				errs <- err
			} else {
				wg.Done()
			}
		}()
	})
	go func() {
		wg.Wait()
		errs <- nil
	}()
	return <-errs
}

func fundImpl(config Config, ctx context.Context, daemonPort string, params FundParams, amountPerKey uint64, password string) error {
	return launchMultiple(ctx, func(ctx context.Context, spawnAction func(func() error)) {
		for i, privkey := range params.Privkeys {
			num := params.Num / len(params.Privkeys)
			if i < params.Num%len(params.Privkeys) {
				num++
			}
			args := []string{
				"advanced", "itn-create-accounts",
				"--amount", strconv.FormatUint(amountPerKey*uint64(num), 10),
				"--fee", strconv.FormatUint(params.Fee, 10),
				"--key-prefix", fmt.Sprintf("%s-%d", params.Prefix, i),
				"--num-accounts", strconv.Itoa(num),
				"--privkey-path", privkey,
			}
			if daemonPort != "" {
				args = append(args, "--daemon-port", daemonPort)
			}
			cmd := exec.CommandContext(ctx, config.MinaExec, args...)
			cmd.Stderr = os.Stderr
			cmd.Stdout = os.Stderr
			cmd.Env = []string{"MINA_PRIVKEY_PASS=" + password}
			spawnAction(cmd.Run)
		}
	})
}

func runImpl(config Config, ctx context.Context, daemonPortIx int, params FundParams, output OutputF) error {
	amountPerKey := params.Amount / uint64(params.Num)
	var err error
	password := ""
	if params.PasswordEnv != "" {
		password, _ = os.LookupEnv(params.PasswordEnv)
	}
	daemonPort := ""
	if len(config.FundDaemonPorts) > 0 {
		daemonPort = config.FundDaemonPorts[daemonPortIx]
	}
	for retryPause := 1; retryPause <= 16; retryPause = retryPause * 2 {
		err = fundImpl(config, ctx, daemonPort, params, amountPerKey, password)
		if err == nil {
			break
		}
		if retryPause <= 8 {
			config.Log.Warnf("Failed to run fund command, retrying in %d minutes: %s", retryPause, err.Error())
			time.Sleep(time.Duration(retryPause) * time.Minute)
		}
		if len(config.FundDaemonPorts) > 0 {
			daemonPortIx = (daemonPortIx + 1) % len(config.FundDaemonPorts)
			daemonPort = config.FundDaemonPorts[daemonPortIx]
		}
	}
	return err
}

func (FundAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params FundParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return runImpl(config, config.Ctx, 0, params, output)
}

func (FundAction) Name() string { return "fund-keys" }

func memorize(cache map[string]struct{}, keys []string) bool {
	for _, k := range keys {
		_, has := cache[k]
		if has {
			return false
		}
		cache[k] = struct{}{}
	}
	return true
}

// Run consequetive commands that do not use common private keys in parallel
func (FundAction) RunMany(config Config, actionIOs []ActionIO) error {
	if len(actionIOs) == 0 {
		return nil
	}
	fundParams := make([]FundParams, len(actionIOs))
	for i, aIO := range actionIOs {
		if err := json.Unmarshal(aIO.Params, &fundParams[i]); err != nil {
			return err
		}
	}
	i := 0
	for i < len(actionIOs) {
		daemonPortIx := 0
		if len(config.FundDaemonPorts) > 0 {
			daemonPortIx = i % len(config.FundDaemonPorts)
		}
		usedKeys := map[string]struct{}{}
		err := launchMultiple(config.Ctx, func(ctx context.Context, spawnAction func(func() error)) {
			for ; i < len(actionIOs); i++ {
				fp := fundParams[i]
				out := actionIOs[i].Output
				if memorize(usedKeys, fp.Privkeys) {
					spawnAction(func() error {
						return runImpl(config, ctx, daemonPortIx, fp, out)
					})
				} else {
					break
				}
			}
		})
		if err != nil {
			return err
		}
	}
	return nil
}

var _ BatchAction = FundAction{}
