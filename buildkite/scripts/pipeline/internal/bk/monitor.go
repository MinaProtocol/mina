package bk

import (
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/buildkite/go-buildkite/v3/buildkite"
)

const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[91m"
	ColorGreen  = "\033[92m"
	ColorYellow = "\033[93m"
	ColorBlue   = "\033[94m"
	ColorGray   = "\033[90m"
)

// Monitor monitors build progress.
type Monitor struct {
	Client         *Client
	BuildNumber    int
	previousStates map[string]string
	ShowAllUpdates bool
}

// NewMonitor creates a new build monitor.
func NewMonitor(client *Client, buildNumber int, showAllUpdates bool) *Monitor {
	return &Monitor{
		Client:         client,
		BuildNumber:    buildNumber,
		previousStates: make(map[string]string),
		ShowAllUpdates: showAllUpdates,
	}
}

// Colorize adds color to text based on state.
func Colorize(text, state string) string {
	color := ColorReset
	switch state {
	case "passed":
		color = ColorGreen
	case "failed":
		color = ColorRed
	case "running":
		color = ColorYellow
	case "scheduled", "assigned":
		color = ColorBlue
	case "canceled", "cancelled", "skipped":
		color = ColorGray
	}
	return color + text + ColorReset
}

// FormatDuration formats a duration nicely.
func FormatDuration(started, finished *buildkite.Timestamp) string {
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

// GetJobName returns the job name.
func GetJobName(job *buildkite.Job) string {
	if job.Name != nil {
		return *job.Name
	}
	return "Unknown"
}

// IsFinalState checks if the build state is terminal.
func IsFinalState(state string) bool {
	return state == "passed" || state == "failed" || state == "canceled" || state == "cancelled"
}

// IsWaiterJob returns true for waiter-type jobs.
func IsWaiterJob(job *buildkite.Job) bool {
	return job.Type != nil && *job.Type == "waiter"
}

// NonWaiterJobs filters out waiter jobs.
func NonWaiterJobs(jobs []*buildkite.Job) []*buildkite.Job {
	result := make([]*buildkite.Job, 0, len(jobs))
	for _, job := range jobs {
		if !IsWaiterJob(job) {
			result = append(result, job)
		}
	}
	return result
}

func (m *Monitor) printJobStatus(job *buildkite.Job) {
	if IsWaiterJob(job) {
		return
	}

	jobID := *job.ID
	state := *job.State
	previousState, exists := m.previousStates[jobID]

	if !m.ShowAllUpdates && exists && previousState == state {
		return
	}

	m.previousStates[jobID] = state

	name := GetJobName(job)
	duration := FormatDuration(job.StartedAt, job.FinishedAt)
	stateText := Colorize(fmt.Sprintf("[%s]", strings.ToUpper(state)), state)
	timestamp := time.Now().Format("15:04:05")

	fmt.Printf("%s %s %s (%s)\n", timestamp, stateText, name, duration)
}

// Run monitors the build until completion.
func (m *Monitor) Run(pollInterval time.Duration) (string, error) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Printf("Monitoring build #%d\n", m.BuildNumber)
	fmt.Printf("%s\n\n", strings.Repeat("=", 80))

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	ticker := time.NewTicker(pollInterval)
	defer ticker.Stop()

	build, err := m.Client.GetBuild(m.BuildNumber)
	if err != nil {
		return "", fmt.Errorf("failed to fetch build: %w", err)
	}

	for !IsFinalState(*build.State) {
		select {
		case <-sigChan:
			fmt.Println("\n\nMonitoring interrupted by user")
			return *build.State, nil
		case <-ticker.C:
			build, err = m.Client.GetBuild(m.BuildNumber)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error fetching build: %v\n", err)
				continue
			}

			for _, job := range build.Jobs {
				m.printJobStatus(job)
			}
		}
	}

	// Final fetch
	build, err = m.Client.GetBuild(m.BuildNumber)
	if err != nil {
		return "", fmt.Errorf("failed to fetch final build state: %w", err)
	}

	for _, job := range build.Jobs {
		m.printJobStatus(job)
	}

	m.PrintSummary(build)
	return *build.State, nil
}

// PrintSummary prints the final build summary.
func (m *Monitor) PrintSummary(build *buildkite.Build) {
	fmt.Printf("\n%s\n", strings.Repeat("=", 80))
	fmt.Printf("Build #%d finished\n", m.BuildNumber)
	fmt.Printf("%s\n", strings.Repeat("=", 80))
	fmt.Printf("State: %s\n", Colorize(strings.ToUpper(*build.State), *build.State))
	fmt.Printf("Duration: %s\n", FormatDuration(build.CreatedAt, build.FinishedAt))
	fmt.Printf("URL: %s\n", *build.WebURL)

	jobs := NonWaiterJobs(build.Jobs)
	if len(jobs) > 0 {
		fmt.Println("\nJob Summary:")
		for _, job := range jobs {
			name := GetJobName(job)
			duration := FormatDuration(job.StartedAt, job.FinishedAt)
			stateText := Colorize(fmt.Sprintf("[%s]", strings.ToUpper(*job.State)), *job.State)
			fmt.Printf("  %s %s (%s)\n", stateText, name, duration)
		}
	}

	fmt.Printf("%s\n\n", strings.Repeat("=", 80))
}

// GetEnvOrDefault returns environment variable value or default.
func GetEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
