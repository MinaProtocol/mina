package itn_orchestrator

import (
	"encoding/json"
	"os"
	"os/exec"
	"strconv"
)

type FundParams struct {
	Amount      uint64
	Fee         uint64
	Prefix      string
	Num         int
	Privkey     string
	PasswordEnv string `json:",omitempty"`
}

type FundAction struct{}

func (FundAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params FundParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	args := []string{
		"advanced", "itn-create-accounts",
		"--amount", strconv.FormatUint(params.Amount, 10),
		"--fee", strconv.FormatUint(params.Fee, 10),
		"--key-prefix", params.Prefix,
		"--num-accounts", strconv.Itoa(params.Num),
		"--privkey-path", params.Privkey,
	}
	if config.Daemon != "" {
		args = append(args, "--daemon-port", config.Daemon)
	}
	cmd := exec.Command(config.MinaExec, args...)
	cmd.Stderr = os.Stderr
	cmd.Stdout = os.Stderr
	password := ""
	if params.PasswordEnv != "" {
		password, _ = os.LookupEnv(params.PasswordEnv)
	}
	cmd.Env = []string{"MINA_PRIVKEY_PASS=" + password}
	return cmd.Run()
}

func (FundAction) Name() string { return "fund-keys" }

var _ Action = FundAction{}
