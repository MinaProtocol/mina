package app

import (
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/hardfork"
	"github.com/spf13/cobra"
)

var (
	cfg = config.DefaultConfig()
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:          "hardfork_test",
	Short:        "Test hardfork functionality for Mina Protocol",
	SilenceUsage: true,
	Long: `A Go application for testing hardfork functionality in the Mina Protocol.

This test validates that a network can successfully transition from one protocol version 
to another through a hardfork mechanism by:

  1. Running a pre-fork network with the main executable
  2. Producing blocks and transactions to ensure network functionality
  3. Extracting the ledger state at a specified slot
  4. Generating hardfork-compatible genesis ledgers
  5. Starting a post-fork network with the fork executable
  6. Verifying the new network continues from the forked state

Example:
  hardfork_test --main-mina-exe /path/to/mina --main-runtime-genesis-ledger /path/to/runtime_genesis_ledger \
    --fork-mina-exe /path/to/mina-fork --fork-runtime-genesis-ledger /path/to/runtime_genesis_ledger-fork
`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Validate required arguments
		if err := cfg.Validate(); err != nil {
			return err
		}

		// Create and run the hardfork test
		return hardfork.NewHardforkTest(cfg).Run()
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	// Required executable paths
	rootCmd.Flags().StringVar(&cfg.MainMinaExe, "main-mina-exe", "", "Path to the main Mina executable (required)")
	rootCmd.Flags().StringVar(&cfg.MainRuntimeGenesisLedger, "main-runtime-genesis-ledger", "", "Path to the main runtime genesis ledger executable (required)")
	rootCmd.Flags().StringVar(&cfg.ForkMinaExe, "fork-mina-exe", "", "Path to the fork Mina executable (required)")
	rootCmd.Flags().StringVar(&cfg.ForkRuntimeGenesisLedger, "fork-runtime-genesis-ledger", "", "Path to the fork runtime genesis ledger executable (required)")

	// Test configuration
	rootCmd.Flags().IntVar(&cfg.SlotTxEnd, "slot-tx-end", cfg.SlotTxEnd, "Slot at which transactions should end")
	rootCmd.Flags().IntVar(&cfg.SlotChainEnd, "slot-chain-end", cfg.SlotChainEnd, "Slot at which chain should end")
	rootCmd.Flags().IntVar(&cfg.BestChainQueryFrom, "best-chain-query-from", cfg.BestChainQueryFrom, "Slot from which to start calling bestchain query")

	// Slot configuration
	rootCmd.Flags().IntVar(&cfg.MainSlot, "main-slot", cfg.MainSlot, "Slot duration in seconds for main version")
	rootCmd.Flags().IntVar(&cfg.ForkSlot, "fork-slot", cfg.ForkSlot, "Slot duration in seconds for fork version")

	// Delay configuration
	rootCmd.Flags().IntVar(&cfg.MainDelayMin, "main-delay", cfg.MainDelayMin, "Delay before genesis slot in minutes for main version")
	rootCmd.Flags().IntVar(&cfg.HfSlotDelta, "hf-slot-delta", cfg.HfSlotDelta, "Difference in slot between slot-chain-end and genesis of new network")

	// Script directory configuration
	rootCmd.Flags().StringVar(&cfg.ScriptDir, "script-dir", cfg.ScriptDir, "Path to the hardfork script directory")

	// Network root dir
	rootCmd.Flags().StringVar(&cfg.Root, "root", cfg.Root, "Directory in which to create a network, please use absolute path")

	// Shutdown timeout configuration
	rootCmd.Flags().IntVar(&cfg.ShutdownTimeoutMinutes, "shutdown-timeout", cfg.ShutdownTimeoutMinutes, "Timeout in minutes to wait for graceful shutdown before forcing kill")

	// Timing configuration
	rootCmd.Flags().IntVar(&cfg.PollingIntervalSeconds, "polling-interval", cfg.PollingIntervalSeconds, "Interval in seconds for polling height checks")
	rootCmd.Flags().IntVar(&cfg.ForkConfigRetryDelaySeconds, "fork-config-retry-delay", cfg.ForkConfigRetryDelaySeconds, "Delay in seconds between fork config fetch retries")
	rootCmd.Flags().IntVar(&cfg.ForkConfigMaxRetries, "fork-config-max-retries", cfg.ForkConfigMaxRetries, "Maximum number of retries for fork config fetch")
	rootCmd.Flags().IntVar(&cfg.NoNewBlocksWaitSeconds, "no-new-blocks-wait", cfg.NoNewBlocksWaitSeconds, "Wait time in seconds to verify no new blocks after chain end")
	rootCmd.Flags().IntVar(&cfg.UserCommandCheckMaxIterations, "user-command-check-max-iterations", cfg.UserCommandCheckMaxIterations, "Max iterations to check for user commands in blocks")
	rootCmd.Flags().IntVar(&cfg.ForkEarliestBlockMaxRetries, "fork-earliest-block-max-retries", cfg.ForkEarliestBlockMaxRetries, "Maximum number of retries to wait for earliest block in fork network")
	rootCmd.Flags().IntVar(&cfg.HTTPClientTimeoutSeconds, "http-timeout", cfg.HTTPClientTimeoutSeconds, "HTTP client timeout in seconds for GraphQL requests")
	rootCmd.Flags().IntVar(&cfg.ClientMaxRetries, "client-max-retries", cfg.ClientMaxRetries, "Maximum number of retries for client requests")
	rootCmd.Flags().Var(&cfg.ForkMethod, "fork-method", "The implementation of fork")

	// Mark required flags
	rootCmd.MarkFlagRequired("main-mina-exe")
	rootCmd.MarkFlagRequired("main-runtime-genesis-ledger")
	rootCmd.MarkFlagRequired("fork-mina-exe")
	rootCmd.MarkFlagRequired("fork-runtime-genesis-ledger")
}
