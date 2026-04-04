// Hardfork Pipeline Runner
//
// A tool for running and monitoring the hardfork package generation pipeline
// on Buildkite with custom environment variables and real-time monitoring.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/minaprotocol/mina/buildkite/scripts/pipeline/internal/bk"
	"github.com/minaprotocol/mina/buildkite/scripts/pipeline/internal/gcs"
)

func main() {
	var (
		branch            = flag.String("branch", bk.GetEnvOrDefault("BUILDKITE_BRANCH", "develop"), "Git branch to build")
		org               = flag.String("org", "o-1-labs-2", "Buildkite organization")
		pipeline          = flag.String("pipeline", "hardfork-package-generation-new", "Buildkite pipeline name")
		message           = flag.String("message", "Custom pipeline run", "Build message")
		version           = flag.String("version", "", "VERSION environment variable")
		codename          = flag.String("codename", "Noble", "CODENAMES environment variable")
		configURL         = flag.String("config-url", "", "CONFIG_JSON_GZ_URL environment variable (full path)")
		configURLPrefix   = flag.String("latest-config-from-prefix", "", "GCS URL prefix to find latest config .gz file (alternative to --config-url)")
		genesisTimestamp  = flag.String("genesis-timestamp", "", "GENESIS_TIMESTAMP environment variable")
		network           = flag.String("network", "Devnet", "NETWORK environment variable")
		repo              = flag.String("repo", "Nightly", "REPO environment variable")
		precomputedPrefix = flag.String("precomputed-prefix", "", "PRECOMPUTED_FORK_BLOCK_PREFIX environment variable")
		useArtifactsFrom  = flag.String("use-artifacts-from", "", "USE_ARTIFACTS_FROM_BUILDKITE_BUILD environment variable")
		codenamesConfig   = flag.String("codenames-config", "", "CODENAMES_CONFIG environment variable (e.g. Noble_Amd64,Bullseye_Amd64). Defaults to <codename>_Amd64")
		ledgerBucket      = flag.String("ledger-bucket", "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net", "MINA_LEDGER_S3_BUCKET environment variable")
		monitor           = flag.Bool("monitor", false, "Monitor build progress in real-time")
		pollInterval      = flag.Int("poll-interval", 10, "Polling interval in seconds")
		showAllUpdates    = flag.Bool("show-all-updates", false, "Show all job states, not just changes")
		apiToken          = flag.String("api-token", os.Getenv("BUILDKITE_API_TOKEN"), "Buildkite API token")
	)

	flag.Parse()

	if *apiToken == "" {
		fmt.Fprintln(os.Stderr, "Error: BUILDKITE_API_TOKEN is required")
		fmt.Fprintln(os.Stderr, "Set it with: export BUILDKITE_API_TOKEN=your_token")
		os.Exit(1)
	}

	client := bk.NewClient(*apiToken, *org, *pipeline)
	fmt.Printf("Using Buildkite: %s/%s\n", *org, *pipeline)
	fmt.Printf("API URL: https://api.buildkite.com/v2/organizations/%s/pipelines/%s/builds\n\n", *org, *pipeline)

	// Resolve config URL
	resolvedConfigURL := *configURL
	if *configURLPrefix != "" {
		if *configURL != "" {
			fmt.Fprintln(os.Stderr, "Warning: Both --config-url and --latest-config-from-prefix provided, using --latest-config-from-prefix")
		}

		ctx := context.Background()
		latestURL, err := gcs.FindLatestConfig(ctx, *configURLPrefix)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error finding latest config: %v\n", err)
			os.Exit(1)
		}
		resolvedConfigURL = latestURL
		fmt.Printf("Using config URL: %s\n\n", resolvedConfigURL)
	}

	// Default CODENAMES_CONFIG
	resolvedCodenamesConfig := *codenamesConfig
	if resolvedCodenamesConfig == "" && *codename != "" {
		codenameParts := strings.Split(*codename, ",")
		var configParts []string
		for _, part := range codenameParts {
			trimmed := strings.TrimSpace(part)
			if trimmed == "" {
				continue
			}
			configParts = append(configParts, trimmed+"_Amd64")
		}
		if len(configParts) > 0 {
			resolvedCodenamesConfig = strings.Join(configParts, ",")
		}
	}

	if resolvedConfigURL == "" {
		fmt.Fprintf(os.Stderr, "error: CONFIG_JSON_GZ_URL (resolvedConfigURL) must be non-empty; refusing to create a build that will immediately fail\n")
		os.Exit(1)
	}

	env := map[string]string{
		"CODENAMES":                          *codename,
		"CODENAMES_CONFIG":                   resolvedCodenamesConfig,
		"NETWORK":                            *network,
		"REPO":                               *repo,
		"GIT_LFS_SKIP_SMUDGE":               "1",
		"MINA_LEDGER_S3_BUCKET":              *ledgerBucket,
		"VERSION":                            *version,
		"CONFIG_JSON_GZ_URL":                 resolvedConfigURL,
		"GENESIS_TIMESTAMP":                  *genesisTimestamp,
		"PRECOMPUTED_FORK_BLOCK_PREFIX":      *precomputedPrefix,
		"USE_ARTIFACTS_FROM_BUILDKITE_BUILD": *useArtifactsFrom,
		"USE_GENERIC_DOCKERS_FROM_VERSION":   "",
		"HARDFORK_GENESIS_SLOT_DELTA":        "",
	}

	fmt.Printf("Creating build on branch '%s'...\n", *branch)
	fmt.Println("Environment variables:")
	for key, value := range env {
		fmt.Printf("  %s: %s\n", key, value)
	}
	fmt.Println()

	build, err := client.CreateBuild(*branch, env, *message)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating build: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Build created successfully!")
	fmt.Printf("Build ID: %s\n", *build.ID)
	fmt.Printf("Build Number: %d\n", *build.Number)
	fmt.Printf("URL: %s\n", *build.WebURL)

	if *monitor {
		buildMonitor := bk.NewMonitor(client, *build.Number, *showAllUpdates)
		finalState, err := buildMonitor.Run(time.Duration(*pollInterval) * time.Second)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error monitoring build: %v\n", err)
			os.Exit(1)
		}

		switch finalState {
		case "passed":
			os.Exit(0)
		case "failed":
			os.Exit(1)
		case "canceled", "cancelled":
			os.Exit(2)
		default:
			os.Exit(3)
		}
	}
}
