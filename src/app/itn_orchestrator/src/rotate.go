package itn_orchestrator

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strconv"
)

type RotateParams struct {
	Pubkeys []string `json:"pubkeys"`

	RestServers []string `json:"servers"`

	// Ratio of each private key's balance to be used in the rotation
	Ratio float64 `json:"ratio"`

	// Mapping is an array of receiver indexes:
	//   - size of array equals `n`
	//   - each index is from `0` to `n - 1` inclusive
	//   - value `j` at index `i` means that in this rotation key `i` sends a payment to key `j`
	Mapping []int `json:"mapping"`

	Fee uint64 `json:"fee,omitempty"`

	PasswordEnv string `json:"passwordEnv,omitempty"`
}

type RotateAction struct{}

func (RotateAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params RotateParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	if len(params.RestServers) != len(params.Pubkeys) {
		return errors.New("length of list of rest servers is not equal to number of key files")
	}
	if len(params.Mapping) != len(params.Pubkeys) {
		return errors.New("length of mapping is not equal to number of key files")
	}
	if params.Ratio < 1e-3 {
		return errors.New("ratio too small")
	}
	password := ""
	if params.PasswordEnv != "" {
		password, _ = os.LookupEnv(params.PasswordEnv)
	}
	for _, m := range params.Mapping {
		if m < 0 || m >= len(params.Pubkeys) {
			return errors.New("wrong index in the mapping")
		}
	}
	balances := make([]uint64, len(params.Pubkeys))
	for i, pk := range params.Pubkeys {
		err := retryOnMultipleServers(params.RestServers, i, "rotate-get-balance", config.Log, func(restServer string) error {
			var err error
			balances[i], err = getBalance(config, restServer, pk)
			return err
		})
		if err != nil {
			return fmt.Errorf("failed to get balance of public key %s: %s", pk, err)
		}
	}
	config.Log.Infof("Retrieved balances for rotation: %v", balances)
	fee := params.Fee
	if fee == 0 {
		fee = 2e9
	}
	for senderIx, receiverIx := range params.Mapping {
		senderPk := params.Pubkeys[senderIx]
		restServer := params.RestServers[senderIx]
		err := unlockPrivkey(config, restServer, senderPk, password)
		if err != nil {
			config.Log.Warnf("Failed to unlock key %s on server %s", senderPk, restServer)
			continue
		}
		amount := uint64(float64(balances[senderIx]-fee) * params.Ratio)
		receiverPk := params.Pubkeys[receiverIx]
		err = sendPayment(config, restServer, senderPk, receiverPk, amount, fee)
		if err == nil {
			config.Log.Infof("Rotated: %s -> %s (%d nanomina)", senderPk, receiverPk, amount)
		} else {
			config.Log.Warnf("Failed to rotate key %s on server %s", senderPk, restServer)
		}
	}
	return nil
}

func (RotateAction) Name() string { return "rotate-balance" }

func getBalance(config Config, restServer, pubkey string) (result uint64, err error) {
	args := []string{
		"client", "get-balance",
		"--public-key", pubkey,
	}
	if restServer != "" {
		args = append(args, "--rest-server", restServer)
	}
	err = execScanMina(config.Ctx, config.MinaExec, args, nil, func(scanner *bufio.Scanner) error {
		for scanner.Scan() {
			if scanner.Text() == "Balance:" && scanner.Scan() {
				balanceStr := scanner.Text()
				if !scanner.Scan() || scanner.Text() != "mina" {
					return errors.New("unexpected currency")
				}
				var err error
				result, err = parseMina(balanceStr)
				return err
			}
		}
		return errors.New("didn't get balance")
	})
	return
}

func formatMina(amount uint64) string {
	s := strconv.FormatUint(amount, 10)
	return s[:len(s)-9] + "." + s[len(s)-9:]
}

func sendPayment(config Config, restServer, senderPk, receiverPk string, amount, fee uint64) error {
	args := []string{
		"client", "send-payment",
		"--sender", senderPk,
		"--receiver", receiverPk,
		"--amount", formatMina(amount),
		"--fee", formatMina(fee),
		"--memo", "rotation",
	}
	if restServer != "" {
		args = append(args, "--rest-server", restServer)
	}
	return execMina(config.Ctx, config.MinaExec, args, nil)
}

func unlockPrivkey(config Config, restServer, pubkey, password string) error {
	args := []string{
		"accounts", "unlock",
		"--public-key", pubkey,
	}
	if restServer != "" {
		args = append(args, "--rest-server", restServer)
	}
	env := []string{"MINA_PRIVKEY_PASS=" + password}
	return execMina(config.Ctx, config.MinaExec, args, env)
}
