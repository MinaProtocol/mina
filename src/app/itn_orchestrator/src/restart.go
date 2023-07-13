package itn_orchestrator

import (
	"encoding/json"
	"errors"
	"os"
	"os/exec"
	"strings"
)

type RestartParams struct {
	Nodes []NodeAddress
	Clean bool
}

type RestartAction struct{}

func (RestartAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	if config.ControlExec == "" {
		return errors.New("no restart exec provided")
	}
	var params RestartParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	var cmd string
	if params.Clean {
		cmd = "redeploy"
	} else {
		cmd = "restart"
	}
	for _, addr := range params.Nodes {
		ip := string(addr[:strings.IndexRune(string(addr), ':')])
		cmd := exec.Command(config.ControlExec, cmd, ip)
		cmd.Stderr = os.Stderr
		cmd.Stdout = os.Stderr
		if err := cmd.Run(); err != nil {
			return err
		}
	}
	return nil
}

func (RestartAction) Name() string { return "restart" }

var _ Action = RestartAction{}
