package hardfork

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// rosettaNetworkName asks the Rosetta server of the fork network for its
// network name, and waits until the server answers.
func (t *HardforkTest) rosettaNetworkName() (string, error) {
	url := fmt.Sprintf("http://localhost:%d/network/list", t.Config.RosettaPort)
	deadline := time.Now().Add(time.Duration(t.Config.ArchiveWaitMinutes) * time.Minute)
	var lastErr error
	for time.Now().Before(deadline) {
		resp, err := http.Post(url, "application/json", strings.NewReader(`{"metadata":{}}`))
		if err == nil {
			body, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()
			if readErr == nil && resp.StatusCode == http.StatusOK {
				var list struct {
					NetworkIdentifiers []struct {
						Network string `json:"network"`
					} `json:"network_identifiers"`
				}
				if err := json.Unmarshal(body, &list); err != nil {
					return "", fmt.Errorf("invalid /network/list answer %s: %w", string(body), err)
				}
				if len(list.NetworkIdentifiers) == 0 {
					return "", fmt.Errorf("Rosetta /network/list has no network: %s", string(body))
				}
				return list.NetworkIdentifiers[0].Network, nil
			}
			lastErr = fmt.Errorf("status %d: %s", resp.StatusCode, string(body))
		} else {
			lastErr = err
		}
		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}
	return "", fmt.Errorf("Rosetta server on port %d did not answer /network/list: %v", t.Config.RosettaPort, lastErr)
}

// fundedRosettaAccount returns the address and the hex private key of the
// account that rosetta-cli uses for its construction check.
func (t *HardforkTest) fundedRosettaAccount() (address string, privkeyHex string, err error) {
	keyFile := t.Config.RosettaFundedKeyFile()
	pub, err := os.ReadFile(keyFile + ".pub")
	if err != nil {
		return "", "", err
	}
	cmd := exec.Command(t.Config.ForkSignerExe, "hex-of-private-key-file", "--private-key-path", keyFile)
	cmd.Env = append(os.Environ(), "MINA_PRIVKEY_PASS="+config.LocalNetworkKeyPassword)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return "", "", fmt.Errorf("mina-ocaml-signer hex-of-private-key-file failed: %w: %s", err, stderr.String())
	}
	lines := strings.Fields(stdout.String())
	if len(lines) == 0 {
		return "", "", fmt.Errorf("mina-ocaml-signer printed no key")
	}
	return strings.TrimSpace(string(pub)), lines[len(lines)-1], nil
}

// prepareRosettaCliConfig copies config.json and mina.ros to dir and fills
// their placeholders. It returns the path of config.json.
func (t *HardforkTest) prepareRosettaCliConfig(dir string, network string) (string, error) {
	address, privkey, err := t.fundedRosettaAccount()
	if err != nil {
		return "", err
	}
	port := strconv.Itoa(t.Config.RosettaPort)
	replacer := strings.NewReplacer(
		"PLACEHOLDER_PREFUNDED_PRIVKEY", privkey,
		"PLACEHOLDER_PREFUNDED_ADDRESS", address,
		"PLACEHOLDER_ROSETTA_ONLINE_PORT", port,
		// One Rosetta server answers both the online and the offline API.
		"PLACEHOLDER_ROSETTA_OFFLINE_PORT", port,
		"PLACEHOLDER_NETWORK_NAME", network,
	)
	for _, name := range []string{"config.json", "mina.ros"} {
		data, err := os.ReadFile(filepath.Join(t.Config.RosettaCliConfigDir, name))
		if err != nil {
			return "", err
		}
		if err := os.WriteFile(filepath.Join(dir, name), []byte(replacer.Replace(string(data))), 0600); err != nil {
			return "", err
		}
	}

	configFile := filepath.Join(dir, "config.json")
	data, err := os.ReadFile(configFile)
	if err != nil {
		return "", err
	}
	var cfg map[string]any
	if err := json.Unmarshal(data, &cfg); err != nil {
		return "", fmt.Errorf("invalid rosetta-cli config.json: %w", err)
	}
	cfg["data_directory"] = filepath.Join(dir, "data")
	data, err = json.MarshalIndent(cfg, "", " ")
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(configFile, data, 0600); err != nil {
		return "", err
	}

	t.Logger.Info("rosetta-cli config for network %s in %s, funded account %s", network, dir, address)
	return configFile, nil
}

func (t *HardforkTest) runRosettaCli(dir string, args ...string) error {
	timeout := time.Duration(t.Config.RosettaCheckTimeoutMinutes) * time.Minute
	ctx, cancel := context.WithTimeout(t.ctx, timeout)
	defer cancel()

	t.Logger.Info("Running rosetta-cli %s...", args[0])
	start := time.Now()
	cmd := exec.CommandContext(ctx, t.Config.RosettaCliExe, args...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("rosetta-cli %s did not complete in %s", args[0], timeout)
		}
		return fmt.Errorf("rosetta-cli %s failed: %w", args[0], err)
	}
	t.Logger.Info("rosetta-cli %s passed in %s", args[0], time.Since(start).Round(time.Second))
	return nil
}

// RunRosettaChecks runs the rosetta-cli checks against the Rosetta server of
// the fork network. That server reads the archive database that both networks
// wrote and that the test repaired.
func (t *HardforkTest) RunRosettaChecks() error {
	network, err := t.rosettaNetworkName()
	if err != nil {
		return err
	}

	dir, err := os.MkdirTemp("", "rosetta-cli")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)

	configFile, err := t.prepareRosettaCliConfig(dir, network)
	if err != nil {
		return err
	}

	checks := [][]string{
		{"configuration:validate", configFile},
		{"check:spec", "--all", "--configuration-file", configFile},
		{"check:construction", "--configuration-file", configFile},
		{"check:data", "--configuration-file", configFile},
	}
	for _, check := range checks {
		if err := t.runRosettaCli(dir, check...); err != nil {
			return err
		}
	}
	return nil
}
