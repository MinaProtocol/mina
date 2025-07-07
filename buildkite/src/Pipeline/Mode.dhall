-- Mode defines pipeline goal
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on stable changes.
-- Triaged - filter eligible jobs based on tags and then apply triage based on changed made in PR
-- Full - filter only eligible jobs and do not perform triage

let Mode = < Triaged | Full >

let capitalName =
          \(pipelineMode : Mode)
      ->  merge { Triaged = "Triaged", Full = "Full" } pipelineMode

let isFull =
          \(pipelineMode : Mode)
      ->  merge { Triaged = False, Full = True } pipelineMode

in  { Type = Mode, capitalName = capitalName, isFull = isFull }
