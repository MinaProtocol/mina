package cmd

import (
	"log/slog"
	"os"

	"github.com/spf13/cobra"
)

var (
	verbose bool
	network string
)

var rootCmd = &cobra.Command{
	Use:   "mina-bootstrap",
	Short: "Fetch and stage Mina node artifacts (archive dumps, precomputed blocks, ledgers).",
	Long: `mina-bootstrap automates the pre-staging steps for running a Mina archive
node, daemon, or Rosetta stack: downloading the latest archive dump from the
Mina Foundation's public buckets, restoring it into Postgres, fetching
precomputed blocks for backfill, and similar tasks that today live as long
curl + gsutil incantations in operator docs and compose stacks.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		level := slog.LevelInfo
		if verbose {
			level = slog.LevelDebug
		}
		slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: level})))
	},
}

func init() {
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "enable debug logging")
	rootCmd.PersistentFlags().StringVar(&network, "network", "mainnet", "Mina network: mainnet, devnet")

	// Archive-node staging verbs are grouped under `archive`
	// (restore/catchup/precomputed); see archive.go. Future domains (ledger,
	// daemon, ...) get their own top-level groups.
	rootCmd.AddCommand(archiveCmd)
}

func Execute() error {
	return rootCmd.Execute()
}
