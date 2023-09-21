-- Mode defines pipeline goal
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on Nightly changes.

let Prelude = ../External/Prelude.dhall

let Mode = < PullRequest | Nightly >

let capitalName = \(pipelineMode : Mode) ->
  merge {
    PullRequest = "PullRequest"
    , Nightly = "Nightly"
  } pipelineMode

in
{ 
    Type = Mode,
    capitalName = capitalName
}