-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.

let SelectFiles = ./Lib/SelectFiles.dhall

let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall

let JobSpec = ./Pipeline/JobSpec.dhall

let Pipeline = ./Pipeline/Dsl.dhall

let Size = ./Command/Size.dhall

let mode = env:BUILDKITE_PIPELINE_MODE as Text ? "Stable"

let selection = env:BUILDKITE_PIPELINE_JOB_SELECTION as Text ? "Triaged"

let tagFilter = env:BUILDKITE_PIPELINE_FILTER as Text ? "FastOnly"

let scopeFilter = env:BUILDKITE_PIPELINE_SCOPE as Text ? "All"

let filterMode = env:BUILDKITE_PIPELINE_FILTER_MODE as Text ? "Any"

let config
    : Pipeline.Config.Type
    = Pipeline.Config::{
      , spec = JobSpec::{
        , name = "prepare"
        , dirtyWhen = [ SelectFiles.everything ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "export BUILDKITE_PIPELINE_MODE=${mode}"
              , Cmd.run "export BUILDKITE_PIPELINE_JOB_SELECTION=${selection}"
              , Cmd.run "export BUILDKITE_PIPELINE_FILTER=${tagFilter}"
              , Cmd.run "export BUILDKITE_PIPELINE_SCOPE=${scopeFilter}"
              , Cmd.run "export BUILDKITE_PIPELINE_FILTER_MODE=${filterMode}"
              , Cmd.quietly
                  "dhall-to-yaml --quoted <<< '(./buildkite/src/Monorepo.dhall) { selection=(./buildkite/src/Pipeline/JobSelection.dhall).Type.${selection}, tagFilter=(./buildkite/src/Pipeline/TagFilter.dhall).Type.${tagFilter}, scopeFilter=(./buildkite/src/Pipeline/ScopeFilter.dhall).Type.${scopeFilter}, filterMode=(./buildkite/src/Pipeline/FilterMode.dhall).Type.${filterMode} }' | buildkite-agent pipeline upload"
              ]
            , label = "Prepare monorepo triage"
            , key = "monorepo-${selection}-${tagFilter}-${scopeFilter}"
            , target = Size.Small
            }
        ]
      }

in  (Pipeline.build config).pipeline
