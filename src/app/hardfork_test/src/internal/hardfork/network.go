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
		extraAccountsPath, err := t.setupDormantWhaleAccount()
		if err != nil {
			return nil, err
		}
		args = append(args,
			"--extra-genesis-accounts", extraAccountsPath,
			"--active-stake-per-whale", strconv.FormatFloat(t.Config.ActiveStakePerWhale, 'f', 0, 64),
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

func (t *HardforkTest) setupDormantWhaleAccount() (string, error) {
	dormantDir, err := os.MkdirTemp("", "dormant-whale-keys")
	if err != nil {
		return "", fmt.Errorf("failed to create temp dir for dormant whale keys: %w", err)
	}

	t.Config.DormantWhaleKeyDir = dormantDir

	keyPath := filepath.Join(dormantDir, "dormant_whale_account")

	cmd := exec.Command(t.Config.MainMinaExe, "advanced", "generate-keypair", "-privkey-path", keyPath)
	cmd.Env = append(os.Environ(), "MINA_PRIVKEY_PASS="+os.Getenv("MINA_PRIVKEY_PASS"))
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("failed to generate dormant whale keypair: %w", err)
	}

	pubkeyBytes, err := os.ReadFile(keyPath + ".pub")
	if err != nil {
		return "", fmt.Errorf("failed to read dormant whale public key: %w", err)
	}
	pubkey := strings.TrimSpace(string(pubkeyBytes))

	t.Config.DormantWhalePk = pubkey

	extraFile := filepath.Join(os.TempDir(), "extra_genesis_accounts.json")
	extra := extraGenesisAccounts{
		Accounts: []extraGenesisAccount{
			{
				Pk:       pubkey,
				Sk:       nil,
				Balance:  config.EncodeNanominas(uint64(t.Config.DormantWhaleBalance * 1e9)),
				Delegate: pubkey,
			},
		},
	}
	data, err := json.Marshal(extra)
	if err != nil {
		return "", fmt.Errorf("failed to marshal extra genesis accounts: %w", err)
	}
	if err := os.WriteFile(extraFile, data, 0644); err != nil {
		return "", fmt.Errorf("failed to write extra genesis accounts: %w", err)
	}

	return extraFile, nil
}
