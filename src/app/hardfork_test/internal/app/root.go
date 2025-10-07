package app

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/internal/hardfork"
	"github.com/spf13/cobra"
)

var (
	cfg = config.DefaultConfig()
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "hardfork_test",
	Short: "Test hardfork functionality for Mina Protocol",
	Long: `A Go application that implements the control flow from scripts/hardfork/test.sh,
allowing for testing of hardfork functionality in the Mina Protocol.

Example:
  hardfork_test --main-mina-exe /path/to/mina --main-runtime-genesis-ledger /path/to/runtime_genesis_ledger \
    --fork-mina-exe /path/to/mina-fork --fork-runtime-genesis-ledger /path/to/runtime_genesis_ledger-fork
`,
	RunE: func(cmd *cobra.Command, args []string) error {
		// Validate required arguments
		if err := cfg.Validate(); err != nil {
			return err
		}
		
		// Create absolute paths
		workDir, err := os.Getwd()
		if err != nil {
			return fmt.Errorf("failed to get working directory: %w", err)
		}
		cfg.WorkDir = workDir
		
		// Create and run the hardfork test
		test := hardfork.NewHardforkTest(cfg)
		return test.Run()
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
	rootCmd.Flags().IntVar(&cfg.MainDelay, "main-delay", cfg.MainDelay, "Delay before genesis slot in minutes for main version")
	rootCmd.Flags().IntVar(&cfg.ForkDelay, "fork-delay", cfg.ForkDelay, "Delay before genesis slot in minutes for fork version")
	
	// Timeout
	rootCmd.Flags().IntVar(&cfg.TimeoutMinutes, "timeout", cfg.TimeoutMinutes, "Timeout for the test in minutes")
	
	// Mark required flags
	rootCmd.MarkFlagRequired("main-mina-exe")
	rootCmd.MarkFlagRequired("main-runtime-genesis-ledger")
	rootCmd.MarkFlagRequired("fork-mina-exe")
	rootCmd.MarkFlagRequired("fork-runtime-genesis-ledger")
}
