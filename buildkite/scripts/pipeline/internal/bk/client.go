package bk

import (
	"fmt"

	"github.com/buildkite/go-buildkite/v3/buildkite"
)

// Client wraps the Buildkite SDK client with org/pipeline context.
type Client struct {
	client   *buildkite.Client
	Org      string
	Pipeline string
}

// NewClient creates a new Buildkite API client using the SDK.
func NewClient(apiToken, org, pipeline string) *Client {
	config, _ := buildkite.NewTokenConfig(apiToken, false)
	client := buildkite.NewClient(config.Client())

	return &Client{
		client:   client,
		Org:      org,
		Pipeline: pipeline,
	}
}

// CreateBuild creates a new build.
func (c *Client) CreateBuild(branch string, env map[string]string, message string) (*buildkite.Build, error) {
	create := &buildkite.CreateBuild{
		Commit:  "HEAD",
		Branch:  branch,
		Message: message,
		Env:     env,
	}

	build, _, err := c.client.Builds.Create(c.Org, c.Pipeline, create)
	if err != nil {
		return nil, fmt.Errorf("failed to create build: %w", err)
	}

	return build, nil
}

// GetBuild retrieves build details by build number.
func (c *Client) GetBuild(buildNumber int) (*buildkite.Build, error) {
	build, _, err := c.client.Builds.Get(c.Org, c.Pipeline, fmt.Sprintf("%d", buildNumber), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get build: %w", err)
	}

	return build, nil
}

// ListBuilds lists builds for the pipeline with the given options.
func (c *Client) ListBuilds(opts *buildkite.BuildsListOptions) ([]buildkite.Build, error) {
	builds, _, err := c.client.Builds.ListByPipeline(c.Org, c.Pipeline, opts)
	if err != nil {
		return nil, fmt.Errorf("failed to list builds: %w", err)
	}

	return builds, nil
}
