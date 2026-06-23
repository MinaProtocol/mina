package cmd

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/download"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/extract"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/networks"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/pg"
)

var (
	archivePgURI   string
	archiveDate    string
	archiveHour    string
	archiveWorkDir string
	archiveSkipPg  bool
)

var archiveCmd = &cobra.Command{
	Use:   "archive",
	Short: "Download a Mina archive dump and restore it into Postgres",
	Long: `Downloads the latest (or a date-pinned) archive dump from the Mina
Foundation's public GCS bucket, extracts it, applies the recommended
Postgres tuning, and loads the SQL into the target database.

Replaces the multi-step curl + tar + psql sequence currently inlined in
the Rosetta docker-compose bootstrap_db service and documented across
the docs2 archive-node setup pages.`,
	RunE: runArchive,
}

func init() {
	archiveCmd.Flags().StringVar(&archivePgURI, "pg-uri", "", "Postgres URI (postgres://user:pw@host:port/db). Required unless --skip-pg.")
	archiveCmd.Flags().StringVar(&archiveDate, "date", "", "Dump date in YYYY-MM-DD form. Defaults to today (UTC).")
	archiveCmd.Flags().StringVar(&archiveHour, "hour", "0000", "Dump hour in HHMM form (dumps are produced hourly). Default 0000 (midnight UTC).")
	archiveCmd.Flags().StringVar(&archiveWorkDir, "work-dir", ".", "Where to download and extract intermediate files.")
	archiveCmd.Flags().BoolVar(&archiveSkipPg, "skip-pg", false, "Download + extract only; skip the psql restore step.")
}

func runArchive(_ *cobra.Command, _ []string) error {
	if !archiveSkipPg && archivePgURI == "" {
		return fmt.Errorf("--pg-uri is required (or pass --skip-pg to download only)")
	}

	net, err := networks.Lookup(network)
	if err != nil {
		return err
	}

	date := archiveDate
	if date == "" {
		date = time.Now().UTC().Format("2006-01-02")
	}
	hour := archiveHour
	if len(hour) != 4 {
		return fmt.Errorf("--hour must be 4 digits (HHMM), got %q", hour)
	}

	tarballName := fmt.Sprintf("%s-%s_%s.sql.tar.gz", net.ArchiveDumpPrefix, date, hour)
	tarballPath := filepath.Join(archiveWorkDir, tarballName)

	ctx := context.Background()

	slog.Info("downloading archive dump",
		"bucket", net.ArchiveDumpBucket, "object", tarballName, "dst", tarballPath)
	if err := download.GCSObject(ctx, net.ArchiveDumpBucket, tarballName, tarballPath); err != nil {
		return fmt.Errorf("download: %w", err)
	}

	slog.Info("extracting", "src", tarballPath, "dst", archiveWorkDir)
	files, err := extract.TarGz(tarballPath, archiveWorkDir)
	if err != nil {
		return fmt.Errorf("extract: %w", err)
	}

	sqlPath := ""
	for _, f := range files {
		if strings.HasSuffix(f, ".sql") {
			sqlPath = f
			break
		}
	}
	if sqlPath == "" {
		return fmt.Errorf("no .sql file found in tarball")
	}
	slog.Info("found sql dump", "path", sqlPath)

	if archiveSkipPg {
		fmt.Fprintf(os.Stdout, "Downloaded + extracted to %s. Skipping psql restore (--skip-pg).\n", sqlPath)
		return nil
	}

	slog.Info("applying postgres tuning")
	if err := pg.ApplyTuning(ctx, archivePgURI); err != nil {
		return fmt.Errorf("tuning: %w", err)
	}

	if err := pg.LoadSQLFile(ctx, archivePgURI, sqlPath); err != nil {
		return fmt.Errorf("load: %w", err)
	}

	fmt.Fprintf(os.Stdout, "Archive bootstrap complete. Restart postgres to apply tuning settings.\n")
	return nil
}
