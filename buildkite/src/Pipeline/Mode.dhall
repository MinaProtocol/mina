-- Mode defines pipeline goal
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on stable changes.
-- PullRequest - filter elligible jobs based on tags and then apply triage based on changed made in PR
-- Stable - filter only ellligigble jobs and do not perform triage

let Mode = < PullRequest | Stable >

let capitalName =
          \(pipelineMode : Mode)
      ->  merge { PullRequest = "PullRequest", Stable = "Stable" } pipelineMode

let isStable =
          \(pipelineMode : Mode)
      ->  merge { PullRequest = False, Stable = True } pipelineMode

in  { Type = Mode, capitalName = capitalName, isStable = isStable }
