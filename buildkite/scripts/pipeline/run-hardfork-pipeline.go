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
	"os/signal"
	"sort"
	"strings"
	"syscall"
	"time"

	"github.com/buildkite/go-buildkite/v3/buildkite"

	"cloud.google.com/go/storage"
	"google.golang.org/api/iterator"
	"google.golang.org/api/option"
)

const (
	colorReset  = "\033[0m"
	colorRed    = "\033[91m"
	colorGreen  = "\033[92m"
	colorYellow = "\033[93m"
	colorBlue   = "\033[94m"
	colorGray   = "\033[90m"

	gcsPrefixGS    = "gs://"
	gcsPrefixHTTPS = "https://storage.googleapis.com/"
)

// BuildkiteClient wraps the Buildkite SDK client with org/pipeline context
type BuildkiteClient struct {
	client   *buildkite.Client
	org      string
	pipeline string
}

// NewBuildkiteClient creates a new Buildkite API client using the SDK
func NewBuildkiteClient(apiToken, org, pipeline string) *BuildkiteClient {
	config, _ := buildkite.NewTokenConfig(apiToken, false)
	client := buildkite.NewClient(config.Client())

	return &BuildkiteClient{
		client:   client,
		org:      org,
		pipeline: pipeline,
	}
}

// CreateBuild creates a new build using the SDK
func (c *BuildkiteClient) CreateBuild(branch string, env map[string]string, message string) (*buildkite.Build, error) {
	create := &buildkite.CreateBuild{
		Commit:  "HEAD",
		Branch:  branch,
		Message: message,
		Env:     env,
	}

	build, _, err := c.client.Builds.Create(c.org, c.pipeline, create)
	if err != nil {
		return nil, fmt.Errorf("failed to create build: %w", err)
	}

	return build, nil
}

// GetBuild retrieves build details using the SDK
func (c *BuildkiteClient) GetBuild(buildNumber int) (*buildkite.Build, error) {
	build, _, err := c.client.Builds.Get(c.org, c.pipeline, fmt.Sprintf("%d", buildNumber), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get build: %w", err)
	}

	return build, nil
}

// BuildMonitor monitors build progress
type BuildMonitor struct {
	client         *BuildkiteClient
	buildNumber    int
	previousStates map[string]string
	showAllUpdates bool
}

// NewBuildMonitor creates a new build monitor
func NewBuildMonitor(client *BuildkiteClient, buildNumber int, showAllUpdates bool) *BuildMonitor {
	return &BuildMonitor{
		client:         client,
		buildNumber:    buildNumber,
		previousStates: make(map[string]string),
		showAllUpdates: showAllUpdates,
	}
}

// colorize adds color to text based on state
func colorize(text, state string) string {
	color := colorReset
	switch state {
	case "passed":
		color = colorGreen
	case "failed":
		color = colorRed
	case "running":
		color = colorYellow
	case "scheduled", "assigned":
		color = colorBlue
	case "canceled", "cancelled", "skipped":
		color = colorGray
	}
	return color + text + colorReset
}

// formatDuration formats a duration nicely
func formatDuration(started, finished *buildkite.Timestamp) string {
	if started == nil {
		return "not started"
	}

	end := time.Now()
	if finished != nil {
		end = finished.Time
	}

	duration := end.Sub(started.Time)
	seconds := int(duration.Seconds())

	if seconds < 60 {
		return fmt.Sprintf("%ds", seconds)
	} else if seconds < 3600 {
		return fmt.Sprintf("%dm %ds", seconds/60, seconds%60)
	}
	hours := seconds / 3600
	minutes := (seconds % 3600) / 60
	return fmt.Sprintf("%dh %dm", hours, minutes)
}

// getJobName returns the job name
func getJobName(job *buildkite.Job) string {
	if job.Name != nil {
		return *job.Name
	}
	return "Unknown"
}

// printJobStatus prints the status of a job
func (m *BuildMonitor) printJobStatus(job *buildkite.Job) {
	// Skip waiter jobs
	if job.Type != nil && *job.Type == "waiter" {
		return
	}

	jobID := *job.ID
	state := *job.State
	previousState, exists := m.previousStates[jobID]

	// Only print if state changed or if showing all updates
	if !m.showAllUpdates && exists && previousState == state {
		return
	}

	m.previousStates[jobID] = state

	name := getJobName(job)
	duration := formatDuration(job.StartedAt, job.FinishedAt)
	stateText := colorize(fmt.Sprintf("[%s]", strings.ToUpper(state)), state)
	timestamp := time.Now().Format("15:04:05")

	fmt.Printf("%s %s %s (%s)\n", timestamp, stateText, name, duration)
}

// Monitor monitors the build until completion
func (m *BuildMonitor) Monitor(pollInterval time.Duration) (string, error) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Printf("Monitoring build #%d\n", m.buildNumber)
	fmt.Printf("%s\n\n", strings.Repeat("=", 80))

	// Set up signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	var build *buildkite.Build
	var err error

	// Initial fetch
	build, err = m.client.GetBuild(m.buildNumber)
	if err != nil {
		return "", fmt.Errorf("failed to fetch build: %w", err)
	}

	for !isFinalState(*build.State) {
		select {
		case <-sigChan:
			fmt.Println("\n\nMonitoring interrupted by user")
			return *build.State, nil
		case <-ticker.C:
			build, err = m.client.GetBuild(m.buildNumber)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error fetching build: %v\n", err)
				continue
			}

			// Print job statuses
			for _, job := range build.Jobs {
				m.printJobStatus(job)
			}
		}
	}

	// Final fetch to ensure we have the latest state
	build, err = m.client.GetBuild(m.buildNumber)
	if err != nil {
		return "", fmt.Errorf("failed to fetch final build state: %w", err)
	}

	// Print all jobs one final time
	for _, job := range build.Jobs {
		m.printJobStatus(job)
	}

	m.printSummary(build)
	return *build.State, nil
}

// isFinalState checks if the build state is final
func isFinalState(state string) bool {
	return state == "passed" || state == "failed" || state == "canceled" || state == "cancelled"
}

// printSummary prints the final build summary
func (m *BuildMonitor) printSummary(build *buildkite.Build) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Printf("Build #%d finished\n", m.buildNumber)
	fmt.Printf("%s\n", strings.Repeat("=", 80))
	fmt.Printf("State: %s\n", colorize(strings.ToUpper(*build.State), *build.State))
	fmt.Printf("Duration: %s\n", formatDuration(build.CreatedAt, build.FinishedAt))
	fmt.Printf("URL: %s\n", *build.WebURL)

	// Job summary
	nonWaiterJobs := make([]*buildkite.Job, 0)
	for _, job := range build.Jobs {
		if job.Type != nil && *job.Type != "waiter" {
			nonWaiterJobs = append(nonWaiterJobs, job)
		}
	}

	if len(nonWaiterJobs) > 0 {
		fmt.Println("\nJob Summary:")
		for _, job := range nonWaiterJobs {
			name := getJobName(job)
			duration := formatDuration(job.StartedAt, job.FinishedAt)
			stateText := colorize(fmt.Sprintf("[%s]", strings.ToUpper(*job.State)), *job.State)
			fmt.Printf("  %s %s (%s)\n", stateText, name, duration)
		}
	}

	fmt.Printf("%s\n\n", strings.Repeat("=", 80))
}

func main() {
	// Command-line flags
	var (
		branch            = flag.String("branch", getEnvOrDefault("BUILDKITE_BRANCH", "develop"), "Git branch to build")
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
		ledgerBucket      = flag.String("ledger-bucket", "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net", "MINA_LEDGER_S3_BUCKET environment variable")
		monitor           = flag.Bool("monitor", false, "Monitor build progress in real-time")
		pollInterval      = flag.Int("poll-interval", 10, "Polling interval in seconds")
		showAllUpdates    = flag.Bool("show-all-updates", false, "Show all job states, not just changes")
		apiToken          = flag.String("api-token", os.Getenv("BUILDKITE_API_TOKEN"), "Buildkite API token")
	)

	flag.Parse()

	// Validate required flags
	if *apiToken == "" {
		fmt.Fprintln(os.Stderr, "Error: BUILDKITE_API_TOKEN is required")
		fmt.Fprintln(os.Stderr, "Set it with: export BUILDKITE_API_TOKEN=your_token")
		os.Exit(1)
	}

	// Create client
	client := NewBuildkiteClient(*apiToken, *org, *pipeline)
	fmt.Printf("Using Buildkite: %s/%s\n", *org, *pipeline)
	fmt.Printf("API URL: https://api.buildkite.com/v2/organizations/%s/pipelines/%s/builds\n\n", *org, *pipeline)

	// Resolve config URL - either use explicit URL or find latest from prefix
	resolvedConfigURL := *configURL
	if *configURLPrefix != "" {
		if *configURL != "" {
			fmt.Fprintln(os.Stderr, "Warning: Both --config-url and --latest-config-from-prefix provided, using --latest-config-from-prefix")
		}

		ctx := context.Background()
		latestURL, err := findLatestConfigFromGCS(ctx, *configURLPrefix)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error finding latest config: %v\n", err)
			os.Exit(1)
		}
		resolvedConfigURL = latestURL
		fmt.Printf("Using config URL: %s\n\n", resolvedConfigURL)
	}

	// Prepare environment variables
	env := map[string]string{
		"CODENAMES":             *codename,
		"NETWORK":               *network,
		"REPO":                  *repo,
		"GIT_LFS_SKIP_SMUDGE":   "1",
		"MINA_LEDGER_S3_BUCKET": *ledgerBucket,
	}

	if *version != "" {
		env["VERSION"] = *version
	}
	if resolvedConfigURL != "" {
		env["CONFIG_JSON_GZ_URL"] = resolvedConfigURL
	}
	if *genesisTimestamp != "" {
		env["GENESIS_TIMESTAMP"] = *genesisTimestamp
	}
	if *precomputedPrefix != "" {
		env["PRECOMPUTED_FORK_BLOCK_PREFIX"] = *precomputedPrefix
	}
	if *useArtifactsFrom != "" {
		env["USE_ARTIFACTS_FROM_BUILDKITE_BUILD"] = *useArtifactsFrom
	}

	// Print configuration
	fmt.Printf("Creating build on branch '%s'...\n", *branch)
	fmt.Println("Environment variables:")
	for key, value := range env {
		fmt.Printf("  %s: %s\n", key, value)
	}
	fmt.Println()

	// Create build
	build, err := client.CreateBuild(*branch, env, *message)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating build: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Build created successfully!")
	fmt.Printf("Build ID: %s\n", *build.ID)
	fmt.Printf("Build Number: %d\n", *build.Number)
	fmt.Printf("URL: %s\n", *build.WebURL)

	// Monitor if requested
	if *monitor {
		buildMonitor := NewBuildMonitor(client, *build.Number, *showAllUpdates)
		finalState, err := buildMonitor.Monitor(time.Duration(*pollInterval) * time.Second)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error monitoring build: %v\n", err)
			os.Exit(1)
		}

		// Exit with appropriate code
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

// getEnvOrDefault returns environment variable value or default
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// findLatestConfigFromGCS finds the latest .gz file with the given GCS URL prefix
// Expected format: gs://bucket/path/prefix or https://storage.googleapis.com/bucket/path/prefix
func findLatestConfigFromGCS(ctx context.Context, urlPrefix string) (string, error) {
	// Parse the URL to extract bucket and prefix
	var bucketName, objectPrefix string

	if strings.HasPrefix(urlPrefix, gcsPrefixGS) {
		// Handle gs:// URLs
		parts := strings.SplitN(strings.TrimPrefix(urlPrefix, gcsPrefixGS), "/", 2)
		bucketName = parts[0]
		if len(parts) > 1 {
			objectPrefix = parts[1]
		}
	} else if strings.HasPrefix(urlPrefix, gcsPrefixHTTPS) {
		// Handle https://storage.googleapis.com URLs
		parts := strings.SplitN(strings.TrimPrefix(urlPrefix, gcsPrefixHTTPS), "/", 2)
		bucketName = parts[0]
		if len(parts) > 1 {
			objectPrefix = parts[1]
		}
	} else {
		return "", fmt.Errorf("invalid GCS URL format, expected %s or %s", gcsPrefixGS, gcsPrefixHTTPS)
	}

	fmt.Printf("Searching for latest config in bucket '%s' with prefix '%s'...\n", bucketName, objectPrefix)

	// Create GCS client - try unauthenticated first for public buckets
	client, err := storage.NewClient(ctx, option.WithoutAuthentication())
	if err != nil {
		return "", fmt.Errorf("failed to create GCS client: %w", err)
	}
	defer client.Close()

	// List objects with the prefix
	bucket := client.Bucket(bucketName)
	query := &storage.Query{
		Prefix: objectPrefix,
	}

	var objects []*storage.ObjectAttrs
	it := bucket.Objects(ctx, query)
	for {
		attrs, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return "", fmt.Errorf("failed to list objects: %w", err)
		}

		// Only include .gz files
		if strings.HasSuffix(attrs.Name, ".gz") {
			objects = append(objects, attrs)
		}
	}

	if len(objects) == 0 {
		return "", fmt.Errorf("no .gz files found with prefix '%s'", objectPrefix)
	}

	// Sort by name (descending) - assumes lexicographic ordering gives us latest
	sort.Slice(objects, func(i, j int) bool {
		return objects[i].Name > objects[j].Name
	})

	latestObject := objects[0]
	latestURL := fmt.Sprintf("https://storage.googleapis.com/%s/%s", bucketName, latestObject.Name)

	fmt.Printf("Found latest config: %s (updated: %s)\n", latestObject.Name, latestObject.Updated.Format(time.RFC3339))
	return latestURL, nil
}
