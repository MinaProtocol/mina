package hardfork

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

type extraGenesisAccount struct {
	Pk       string      `json:"pk"`
	Sk       interface{} `json:"sk"`
	Balance  string      `json:"balance"`
	Delegate interface{} `json:"delegate"`
}

type extraGenesisAccounts struct {
	Accounts []extraGenesisAccount `json:"accounts"`
}

func (t *HardforkTest) setupDormantWhaleAccount(root string) error {
	dormantWhaleDir := filepath.Join(root, "dormant_whale_keys")
	if err := os.MkdirAll(dormantWhaleDir, 0755); err != nil {
		return fmt.Errorf("failed to create dormant whale key directory: %w", err)
	}
	t.Config.DormantWhaleKeyDir = dormantWhaleDir

	privkeyPath := filepath.Join(dormantWhaleDir, "dormant_whale_account")
	genCmd := exec.Command(t.Config.MainMinaExe, "advanced", "generate-keypair", "-privkey-path", privkeyPath)
	genCmd.Env = append(os.Environ(), "MINA_PRIVKEY_PASS=naughty blue worm")
	genCmd.Stdout = os.Stdout
	genCmd.Stderr = os.Stderr
	if err := genCmd.Run(); err != nil {
		return fmt.Errorf("failed to generate dormant whale keypair: %w", err)
	}

	pubkeyBytes, err := os.ReadFile(privkeyPath + ".pub")
	if err != nil {
		return fmt.Errorf("failed to read dormant whale public key: %w", err)
	}
	t.Config.DormantWhalePk = strings.TrimSpace(string(pubkeyBytes))
	t.Logger.Info("Dormant whale public key: %s", t.Config.DormantWhalePk)

	extraFile := filepath.Join(os.TempDir(), "extra_genesis_accounts.json")
	extra := extraGenesisAccounts{
		Accounts: []extraGenesisAccount{
			{
				Pk:       t.Config.DormantWhalePk,
				Sk:       nil,
				Balance:  t.Config.DormantWhaleBalance,
				Delegate: nil,
			},
		},
	}
	data, err := json.Marshal(extra)
	if err != nil {
		return fmt.Errorf("failed to marshal extra genesis accounts: %w", err)
	}
	if err := os.WriteFile(extraFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write extra genesis accounts: %w", err)
	}
	t.Config.DormantWhaleKeyDir = dormantWhaleDir
	return nil
}

func (t *HardforkTest) startLocalNetwork(minaExecutable string, profile string, extraArgs []string) (*exec.Cmd, error) {

	t.Logger.Info("Starting network %s...", profile)
	cmd := exec.Command(
		filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.sh"),
		"--seed", fmt.Sprintf("spawn:%d", t.Config.SeedStartPort),
		"--snark-coordinator-start-port", strconv.Itoa(t.Config.SnarkCoordinatorPort),

		"--whale-start-port", strconv.Itoa(t.Config.WhaleStartPort),
		"--fish-start-port", strconv.Itoa(t.Config.FishStartPort),
		"--node-start-port", strconv.Itoa(t.Config.NodeStartPort),
		"--whales", strconv.Itoa(t.Config.NumWhales),
		"--fish", strconv.Itoa(t.Config.NumFish),
		"--nodes", strconv.Itoa(t.Config.NumNodes),
		"--log-level", "Info",
		"--file-log-level", "Trace",
		"--value-transfer-txns",
		"--transaction-interval", strconv.Itoa(t.Config.PaymentInterval),
		"--root", t.Config.Root,
	)

	cmd.Args = append(cmd.Args, extraArgs...)
	tmpDir, err := os.MkdirTemp("", "mina-hf-tmp-")
	if err != nil {
		return nil, fmt.Errorf("failed to create temp dir: %w", err)
	}
	cmd.Env = append(os.Environ(),
		"MINA_EXE="+minaExecutable,
		"TMPDIR="+tmpDir,
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Start command
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start main network: %w", err)
	}

	// Register command for cleanup on interrupt
	t.registerCmd(cmd)

	t.Logger.Info("Network %s started successfully", profile)
	return cmd, nil
}

// RunMainNetwork starts the main network
func (t *HardforkTest) RunMainNetwork(extraFilesRoot string, mainGenesisTs int64) (*exec.Cmd, error) {

	mainGenesisTimestamp := config.FormatTimestamp(mainGenesisTs)

	if t.Config.UnstakingTest {
		if err := t.setupDormantWhaleAccount(t.Config.Root); err != nil {
			return nil, fmt.Errorf("failed to setup dormant whale: %w", err)
		}
	}

	args := []string{
		"--update-genesis-timestamp", fmt.Sprintf("fixed:%s", mainGenesisTimestamp),
		"--config", "reset",
		"--override-slot-time", strconv.Itoa(t.Config.MainSlot * 1000),
		"--slot-transaction-end", strconv.Itoa(t.Config.SlotTxEnd),
		"--slot-chain-end", strconv.Itoa(t.Config.SlotChainEnd),
		"--hardfork-genesis-slot-delta", strconv.Itoa(t.Config.HfSlotDelta),
		"--extra-files-root", extraFilesRoot,
	}

	if t.Config.UnstakingTest {
		args = append(args,
			"--extra-genesis-accounts",
			filepath.Join(os.TempDir(), "extra_genesis_accounts.json"),
		)
	}

	return t.startLocalNetwork(t.Config.MainMinaExe, "main", args)
}

// RunForkNetwork starts the fork network with hardfork configuration
func (t *HardforkTest) RunForkNetwork() (*exec.Cmd, error) {
	return t.startLocalNetwork(t.Config.ForkMinaExe, "fork", []string{
		"--config", "inherit",
		"--override-slot-time", strconv.Itoa(t.Config.ForkSlot * 1000)},
	)
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, genesisSlot int) {
	t.WaitForBestTip(t.Config.AnyDaemon().Port(config.PORT_REST), func(block client.BlockData) bool {
		return block.Slot >= t.Config.BestChainQueryFrom+genesisSlot
	}, fmt.Sprintf("best tip reached slot %d", t.Config.BestChainQueryFrom),
		time.Duration(2*t.Config.BestChainQueryFrom*slotDurationSec)*time.Second,
	)
}
