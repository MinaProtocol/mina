package itn_orchestrator

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"sync"
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
	var wg sync.WaitGroup
	errs := make(chan error)
	cmds := make([]*exec.Cmd, len(params.Privkeys))
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
		cmd := exec.Command(config.MinaExec, args...)
		cmds[i] = cmd
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
		for _, cmd := range cmds {
			_ = cmd.Cancel()
		}
		return err
	}
	return nil
}

func (FundAction) Name() string { return "fund-keys" }

var _ Action = FundAction{}
