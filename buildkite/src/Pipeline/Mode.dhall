-- Mode defines pipeline goal
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on stable changes.

let Prelude = ../External/Prelude.dhall

let Mode = < PullRequest | Stable >

let capitalName = \(pipelineMode : Mode) ->
  merge {
    PullRequest = "PullRequest"
    , Stable = "Stable"
  } pipelineMode

in
{ 
    Type = Mode,
    capitalName = capitalName
}