// Nightly Promoter
//
// Fetches the latest nightly build from Buildkite, verifies that all Debian
// and Docker jobs passed, and runs the publish command via manager.sh.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/buildkite/go-buildkite/v3/buildkite"
	"github.com/minaprotocol/mina/buildkite/scripts/pipeline/internal/bk"
)

const (
	defaultPipeline          = "mina-mainline-branches-nightlies"
	defaultOrg               = "o-1-labs-2"
	defaultArtifacts         = "mina-logproc,mina-daemon,mina-archive,mina-rosetta,mina-generic"
	defaultLightnetArtifacts = "mina-logproc,mina-generic"
	defaultNetworks          = "devnet"
	defaultCodenames         = "noble,bookworm"
	defaultArchs             = "amd64,arm64"
	defaultDebianRepo        = "nightly.apt.packages.minaprotocol.com"
	defaultSignKey           = "386E9DAC378726A48ED5CE56ADB30D9ACE02F414"
	defaultBackend           = "local"
	defaultProfile           = "lightnet"
	defaultSourceDockerRepo  = "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo"
	defaultTargetDockerRepo  = "gcr.io/o1labs-192920"
)

func main() {
	var (
		branch           = flag.String("branch", "", "Target branch (required)")
		profile          = flag.String("profile", defaultProfile, "Dune profile: lightnet|devnet")
		channel          = flag.String("channel", "", "Debian channel (default: same as branch)")
		org              = flag.String("org", defaultOrg, "Buildkite organization")
		pipeline         = flag.String("pipeline", defaultPipeline, "Buildkite pipeline name")
		dryRun           = flag.Bool("dry-run", false, "Print what would be run without executing")
		force            = flag.Bool("force", false, "Run even if build is not from today")
		apiToken         = flag.String("api-token", "", "Buildkite API token (default: from env)")
		artifacts        = flag.String("artifacts", defaultArtifacts, "Comma-separated artifacts to publish")
		networks         = flag.String("networks", defaultNetworks, "Comma-separated networks")
		codenames        = flag.String("codenames", defaultCodenames, "Comma-separated codenames")
		archs            = flag.String("archs", defaultArchs, "Comma-separated architectures")
		debRepo          = flag.String("debian-repo", defaultDebianRepo, "Debian repository")
		signKey          = flag.String("debian-sign-key", defaultSignKey, "Debian signing key ID")
		backend          = flag.String("backend", defaultBackend, "Storage backend")
		sourceDockerRepo = flag.String("source-docker-repo", defaultSourceDockerRepo, "Source Docker repository where nightly builds are pushed")
		targetDockerRepo = flag.String("target-docker-repo", defaultTargetDockerRepo, "Target Docker repository for promoted images")
		onlyDebians      = flag.Bool("only-debians", false, "Only publish Debian packages (skip Docker)")
		onlyDockers      = flag.Bool("only-dockers", false, "Only publish Docker images (skip Debians)")
		exportEnv        = flag.String("export-env", "", "Write resolved build info to a shell-sourceable file")
	)

	flag.Parse()

	// Lightnet builds only produce a subset of artifacts (LogProc + DaemonAppsOnly).
	// Auto-select the lightnet artifact list when profile is lightnet and the user
	// hasn't explicitly overridden --artifacts.
	if *profile == "lightnet" && *artifacts == defaultArtifacts {
		*artifacts = defaultLightnetArtifacts
		fmt.Printf("Profile is lightnet — using lightnet artifact list: %s\n", *artifacts)
	}

	if *branch == "" {
		fmt.Fprintln(os.Stderr, "Error: --branch is required")
		flag.Usage()
		os.Exit(1)
	}

	// Resolve API token: prefer BUILDKITE_AGENT_WRITE_TOKEN (works for REST API),
	// then BUILDKITE_API_TOKEN, then BUILDKITE_AGENT_ACCESS_TOKEN.
	// This matches the pattern used by run_for_newest_devnet.sh (hardfork runner).
	if *apiToken == "" {
		tokenEnvVars := []string{
			"BUILDKITE_AGENT_WRITE_TOKEN",
			"BUILDKITE_API_TOKEN",
			"BUILDKITE_AGENT_ACCESS_TOKEN",
		}
		for _, env := range tokenEnvVars {
			if t := os.Getenv(env); t != "" {
				fmt.Printf("Using token from %s\n", env)
				*apiToken = t
				break
			}
		}
		if *apiToken == "" {
			fmt.Fprintln(os.Stderr, "Error: No Buildkite API token found.")
			fmt.Fprintln(os.Stderr, "Checked: BUILDKITE_AGENT_WRITE_TOKEN, BUILDKITE_API_TOKEN, BUILDKITE_AGENT_ACCESS_TOKEN")
			fmt.Fprintln(os.Stderr, "Provide --api-token flag or ensure one of the above env vars is set.")
			os.Exit(1)
		}
	} else {
		fmt.Println("Using token from --api-token flag")
	}

	if *channel == "" {
		*channel = *branch
	}

	client := bk.NewClient(*apiToken, *org, *pipeline)

	// Fetch latest build for branch (any state - we check individual jobs)
	fmt.Printf("Fetching latest build for branch '%s' from %s...\n", *branch, *pipeline)

	builds, err := client.ListBuilds(&buildkite.BuildsListOptions{
		Branch:      []string{*branch},
		ListOptions: buildkite.ListOptions{PerPage: 1},
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching builds: %v\n", err)
		os.Exit(1)
	}

	if len(builds) == 0 {
		fmt.Fprintf(os.Stderr, "Error: No builds found for branch '%s'\n", *branch)
		os.Exit(1)
	}

	build := builds[0]
	fmt.Printf("%sFound build #%d%s\n", bk.ColorGreen, *build.Number, bk.ColorReset)
	fmt.Printf("  Build ID:   %s\n", *build.ID)
	fmt.Printf("  Commit:     %s\n", *build.Commit)
	fmt.Printf("  Created at: %s\n", build.CreatedAt.Format(time.RFC3339))
	fmt.Printf("  State:      %s\n", bk.Colorize(*build.State, *build.State))
	fmt.Printf("  URL:        %s\n", *build.WebURL)

	// Check if build is from today
	buildDate := build.CreatedAt.Format("2006-01-02")
	today := time.Now().Format("2006-01-02")

	if buildDate != today {
		fmt.Printf("\n%sWARNING: Latest build is from %s, not today (%s).%s\n", bk.ColorYellow, buildDate, today, bk.ColorReset)
		if !*force {
			fmt.Printf("%sUse --force to run anyway.%s\n", bk.ColorYellow, bk.ColorReset)
			os.Exit(0)
		}
		fmt.Printf("%s--force specified, continuing anyway.%s\n", bk.ColorYellow, bk.ColorReset)
	} else {
		fmt.Printf("\n%sBuild is from today (%s).%s\n", bk.ColorGreen, today, bk.ColorReset)
	}

	// Check that all Debian and Docker jobs passed
	fmt.Println("\nChecking Debian and Docker job statuses...")
	buildFinished := *build.State == "passed" || *build.State == "failed" || *build.State == "canceled"
	allPassed, failedJobs, pendingJobs := checkPackageJobs(build.Jobs, buildFinished)

	if len(pendingJobs) > 0 {
		fmt.Printf("\n%sPending/running jobs:%s\n", bk.ColorYellow, bk.ColorReset)
		for _, name := range pendingJobs {
			fmt.Printf("  - %s\n", name)
		}
		fmt.Fprintln(os.Stderr, "\nError: Some Debian/Docker jobs are still running. Wait for them to complete.")
		os.Exit(1)
	}

	if !allPassed {
		fmt.Printf("\n%sFailed jobs:%s\n", bk.ColorRed, bk.ColorReset)
		for _, name := range failedJobs {
			fmt.Printf("  - %s\n", name)
		}
		fmt.Fprintln(os.Stderr, "\nError: Not all Debian/Docker jobs passed. Cannot promote.")
		os.Exit(1)
	}

	fmt.Printf("%sAll Debian and Docker jobs passed.%s\n", bk.ColorGreen, bk.ColorReset)

	// Compute SOURCE_VERSION and TARGET_VERSION from git
	commit := *build.Commit
	sourceVersion, targetVersion, gitTag, err := computeVersions(commit, *branch)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error computing versions: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\nSOURCE_VERSION: %s\n", sourceVersion)
	fmt.Printf("TARGET_VERSION: %s\n", targetVersion)

	// Compute docker tags: latest-<branch>, <date>-<branch>, <tag>.<date>-<branch>
	todayDate := time.Now().Format("20060102")
	dockerTags := []string{
		fmt.Sprintf("latest-%s", *branch),
		fmt.Sprintf("%s-%s", todayDate, *branch),
		fmt.Sprintf("%s.%s-%s", gitTag, todayDate, *branch),
	}

	// Export resolved values for use by other pipeline steps
	if *exportEnv != "" {
		envContent := fmt.Sprintf(
			"export NIGHTLY_BUILD_ID=%s\n"+
				"export NIGHTLY_SOURCE_VERSION=%s\n"+
				"export NIGHTLY_TARGET_VERSION=%s\n"+
				"export NIGHTLY_GIT_TAG=%s\n"+
				"export NIGHTLY_DOCKER_TAGS=\"%s\"\n"+
				"export NIGHTLY_COMMIT=%s\n",
			*build.ID, sourceVersion, targetVersion, gitTag,
			strings.Join(dockerTags, " "), commit,
		)
		if err := os.WriteFile(*exportEnv, []byte(envContent), 0644); err != nil {
			fmt.Fprintf(os.Stderr, "Error writing export env file: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("Exported build info to %s\n", *exportEnv)
	}

	// Run manager.sh publish
	managerPath := findManagerScript()

	commonArgs := []string{
		"--artifacts", *artifacts,
		"--networks", *networks,
		"--buildkite-build-id", *build.ID,
		"--backend", *backend,
		"--channel", *channel,
		"--source-version", sourceVersion,
		"--codenames", *codenames,
		"--profile", *profile,
	}

	debianArgs := append([]string{"publish"},
		append(commonArgs,
			"--target-version", targetVersion,
			"--debian-repo", *debRepo,
			"--only-debians",
			"--archs", *archs,
			"--debian-sign-key", *signKey,
			"--force-upload-debians",
		)...,
	)

	publishEnv := append(os.Environ(),
		"BUILDKITE_BUILD_ID="+*build.ID,
		"SOURCE_VERSION="+sourceVersion,
	)

	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Println("Publish Configuration")
	fmt.Printf("%s\n", strings.Repeat("=", 80))
	fmt.Printf("  BUILDKITE_BUILD_ID: %s\n", *build.ID)
	fmt.Printf("  SOURCE_VERSION:     %s\n", sourceVersion)
	fmt.Printf("  TARGET_VERSION:     %s\n", targetVersion)
	fmt.Printf("  Channel:            %s\n", *channel)
	fmt.Printf("  Profile:            %s\n", *profile)
	fmt.Printf("  Artifacts:          %s\n", *artifacts)
	fmt.Printf("  Networks:           %s\n", *networks)
	fmt.Printf("  Codenames:          %s\n", *codenames)
	fmt.Printf("  Architectures:      %s\n", *archs)
	fmt.Printf("  Debian repo:        %s\n", *debRepo)
	fmt.Printf("  Source Docker repo: %s\n", *sourceDockerRepo)
	fmt.Printf("  Target Docker repo: %s\n", *targetDockerRepo)
	fmt.Printf("  Docker tags:        %s\n", strings.Join(dockerTags, ", "))
	fmt.Printf("  Backend:            %s\n", *backend)
	fmt.Printf("%s\n", strings.Repeat("=", 80))

	publishDebians := !*onlyDockers
	publishDockers := !*onlyDebians

	if *dryRun {
		fmt.Printf("\n%s[DRY RUN] Would execute:%s\n", bk.ColorYellow, bk.ColorReset)
		if publishDebians {
			fmt.Printf("  %s %s\n", managerPath, strings.Join(debianArgs, " "))
		}
		if publishDockers {
			for _, tag := range dockerTags {
				dockerArgs := buildDockerArgs(commonArgs, tag, *sourceDockerRepo, *targetDockerRepo)
				fmt.Printf("  %s %s\n", managerPath, strings.Join(dockerArgs, " "))
			}
		}
		return
	}

	// Step 1: Publish Debian packages (requires GPG, deb-s3 — runs inside Docker)
	if publishDebians {
		fmt.Println("\nPublishing Debian packages...")
		cmd := exec.Command(managerPath, debianArgs...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Env = publishEnv

		if err := cmd.Run(); err != nil {
			fmt.Fprintf(os.Stderr, "Error running manager.sh publish (debians): %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("%sDebian publish completed.%s\n", bk.ColorGreen, bk.ColorReset)
	}

	// Step 2: Publish Docker images (requires Docker daemon — runs on host)
	if publishDockers {
		for i, tag := range dockerTags {
			fmt.Printf("\nPublishing Docker image [%d/%d] tag=%s...\n", i+1, len(dockerTags), tag)
			dockerArgs := buildDockerArgs(commonArgs, tag, *sourceDockerRepo, *targetDockerRepo)
			cmd := exec.Command(managerPath, dockerArgs...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			cmd.Env = publishEnv

			if err := cmd.Run(); err != nil {
				fmt.Fprintf(os.Stderr, "Error running manager.sh publish (docker tag=%s): %v\n", tag, err)
				os.Exit(1)
			}
		}
	}

	fmt.Printf("\n%sAll publish steps completed successfully.%s\n", bk.ColorGreen, bk.ColorReset)
}

// buildDockerArgs creates manager.sh args for publishing a single Docker tag.
func buildDockerArgs(commonArgs []string, tag, sourceDockerRepo, targetDockerRepo string) []string {
	return append([]string{"publish"},
		append(commonArgs,
			"--verify",
			"--target-version", tag,
			"--only-dockers",
			"--source-docker-repo", sourceDockerRepo,
			"--target-docker-repo", targetDockerRepo,
			"--force-upload-debians",
		)...,
	)
}

// checkPackageJobs checks all Debian: and Docker: prefixed jobs.
// When buildFinished is true, jobs still showing as "running" are treated as
// failed (Buildkite API quirk: cancelled/timed-out jobs can show as running).
// Returns (allPassed, failedJobNames, pendingJobNames).
func checkPackageJobs(jobs []*buildkite.Job, buildFinished bool) (bool, []string, []string) {
	var failed, pending []string
	found := 0

	for _, job := range jobs {
		if bk.IsWaiterJob(job) {
			continue
		}

		name := bk.GetJobName(job)
		if !strings.HasPrefix(name, "Debian:") && !strings.HasPrefix(name, "Docker:") {
			continue
		}

		found++
		state := ""
		if job.State != nil {
			state = *job.State
		}

		switch state {
		case "passed":
			// ok
		case "failed", "canceled", "timed_out", "broken":
			failed = append(failed, fmt.Sprintf("%s [%s]", name, state))
		default:
			// running, scheduled, assigned, etc.
			if buildFinished {
				// Build is done but job still shows as running — treat as failed
				failed = append(failed, fmt.Sprintf("%s [%s, build finished]", name, state))
			} else {
				pending = append(pending, fmt.Sprintf("%s [%s]", name, state))
			}
		}
	}

	if found == 0 {
		fmt.Printf("%sWARNING: No Debian/Docker jobs found in build.%s\n", bk.ColorYellow, bk.ColorReset)
	} else {
		fmt.Printf("Found %d Debian/Docker jobs.\n", found)
	}

	return len(failed) == 0 && len(pending) == 0, failed, pending
}

// computeVersions derives SOURCE_VERSION, TARGET_VERSION, and the base git tag.
// SOURCE_VERSION = <tag>-<branch>-<shorthash> (matches export-git-env-vars.sh MINA_DEB_VERSION)
// TARGET_VERSION = <tag>-<YYYYMMDD>
func computeVersions(commit, branch string) (string, string, string, error) {
	shortHash := commit
	if len(shortHash) > 7 {
		shortHash = shortHash[:7]
	}

	gitTag, err := findNumericTag(commit)
	if err != nil {
		return "", "", "", fmt.Errorf("cannot determine git tag for %s: %w\nTry: git fetch --tags --force", commit, err)
	}

	branchSanitized := sanitizeBranch(branch)
	sourceVersion := fmt.Sprintf("%s-%s-%s", gitTag, branchSanitized, shortHash)
	targetVersion := fmt.Sprintf("%s-%s", gitTag, time.Now().Format("20060102"))

	return sourceVersion, targetVersion, gitTag, nil
}

// findNumericTag finds the most recent tag starting with a digit reachable from ref.
func findNumericTag(ref string) (string, error) {
	for i := 0; i < 20; i++ { // safety limit
		out, err := exec.Command("git", "describe", "--always", "--abbrev=0", ref).CombinedOutput()
		if err != nil {
			return "", fmt.Errorf("git describe failed: %s", strings.TrimSpace(string(out)))
		}

		tag := sanitizeBranch(strings.TrimSpace(string(out)))
		if len(tag) > 0 && tag[0] >= '0' && tag[0] <= '9' {
			return tag, nil
		}
		ref = tag + "~"
	}
	return "", fmt.Errorf("no numeric tag found within 20 ancestors")
}

// sanitizeBranch replaces /, _, # with - to match export-git-env-vars.sh logic.
func sanitizeBranch(s string) string {
	r := strings.NewReplacer("/", "-", "_", "-", "#", "-")
	return r.Replace(s)
}

// findManagerScript locates manager.sh relative to the binary or repo root.
func findManagerScript() string {
	// Try relative to this binary's location (expected in buildkite/scripts/pipeline/bin/)
	execPath, err := os.Executable()
	if err == nil {
		candidate := filepath.Join(filepath.Dir(execPath), "..", "..", "release", "manager.sh")
		if abs, err := filepath.Abs(candidate); err == nil {
			if _, err := os.Stat(abs); err == nil {
				return abs
			}
		}
	}

	// Try relative to working directory (expected at repo root)
	candidate := "buildkite/scripts/release/manager.sh"
	if _, err := os.Stat(candidate); err == nil {
		if abs, err := filepath.Abs(candidate); err == nil {
			return abs
		}
	}

	// Fallback
	fmt.Fprintf(os.Stderr, "Warning: could not locate manager.sh, using relative path\n")
	return "buildkite/scripts/release/manager.sh"
}
