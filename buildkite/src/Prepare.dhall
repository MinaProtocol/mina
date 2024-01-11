-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.

let SelectFiles = ./Lib/SelectFiles.dhall
let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall
let Docker = ./Command/Docker/Type.dhall
let JobSpec = ./Pipeline/JobSpec.dhall
let Pipeline = ./Pipeline/Dsl.dhall
let PipelineMode = ./Pipeline/Mode.dhall
let PipelineFilter = ./Pipeline/Filter.dhall
let PipelineTag = ./Pipeline/Tag.dhall
let Size = ./Command/Size.dhall
let triggerCommand = ./Pipeline/TriggerCommand.dhall

let mode = env:BUILDKITE_PIPELINE_MODE as Text ? "PullRequest"
let filter = env:BUILDKITE_PIPELINE_FILTER as Text ? "FastOnly"

let config : Pipeline.Config.Type = Pipeline.Config::{
  spec = JobSpec::{
    name = "prepare",
    -- TODO: Clean up this code so we don't need an unused dirtyWhen here
    dirtyWhen = [ SelectFiles.everything ]
  },
  steps = [
    Command.build Command.Config::{
      commands = [
        Cmd.run "export BUILDKITE_PIPELINE_MODE=${mode}",
        Cmd.run "export BUILDKITE_PIPELINE_FILTER=${filter}",
        Cmd.run "./buildkite/scripts/generate-jobs.sh > buildkite/src/gen/Jobs.dhall",
        Cmd.quietly "dhall-to-yaml --quoted <<< '(./buildkite/src/Monorepo.dhall) { mode=(./buildkite/src/Pipeline/Mode.dhall).Type.${mode}, filter=(./buildkite/src/Pipeline/Filter.dhall).Type.${filter}  }' | buildkite-agent pipeline upload"
      ],
      label = "Prepare monorepo triage",
      key = "monorepo-${mode}-${filter}",
      target = Size.Small,
      docker = Some Docker::{
        image = (./Constants/ContainerImages.dhall).toolchainBase,
        environment = ["BUILDKITE_AGENT_ACCESS_TOKEN"]
      }
    }
  ]
}
in (Pipeline.build config).pipeline
