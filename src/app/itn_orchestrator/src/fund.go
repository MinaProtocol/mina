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
	Amount      uint64
	Fee         uint64
	Prefix      string
	Num         int
	Privkeys    []string
	PasswordEnv string `json:",omitempty"`
}

type FundAction struct{}

func fundImpl(config Config, params FundParams, amountPerKey uint64, password string) error {
	var wg sync.WaitGroup
	errs := make(chan error)
	ctx, cancelF := context.WithCancel(config.Ctx)
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
		if config.Daemon != "" {
			args = append(args, "--daemon-port", config.Daemon)
		}
		cmd := exec.CommandContext(ctx, config.MinaExec, args...)
		cmd.Stderr = os.Stderr
		cmd.Stdout = os.Stderr
		cmd.Env = []string{"MINA_PRIVKEY_PASS=" + password}
		wg.Add(1)
		go func() {
			if err := cmd.Run(); err != nil {
				errs <- err
			} else {
				wg.Done()
			}
		}()
	}
	go func() {
		wg.Wait()
		errs <- nil
	}()
	err := <-errs
	if err != nil {
		cancelF()
	}
	return err
}

func (FundAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params FundParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	password := ""
	if params.PasswordEnv != "" {
		password, _ = os.LookupEnv(params.PasswordEnv)
	}
	amountPerKey := params.Amount / uint64(params.Num)
	var err error
	for retryPause := 1; retryPause <= 8; retryPause = retryPause * 2 {
		err = fundImpl(config, params, amountPerKey, password)
		if err == nil {
			break
		}
		config.Log.Warnf("Failed to run fund command, retrying in %d minutes: %s", retryPause, err.Error())
		time.Sleep(time.Duration(retryPause) * time.Minute)
	}
	return err
}

func (FundAction) Name() string { return "fund-keys" }

var _ Action = FundAction{}
