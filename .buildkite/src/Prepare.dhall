-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.

let Command = ./Lib/Command.dhall
let JobSpec = ./Lib/JobSpec.dhall
let Pipeline = ./Lib/Pipeline.dhall
let Size = ./Lib/Size.dhall
let triggerCommand = ./Lib/TriggerCommand.dhall

let config : Pipeline.Config.Type = Pipeline.Config::{
  spec = JobSpec::{
    name = "prepare",
    -- TODO: Clean up this code so we don't need an unused dirtyWhen here
    dirtyWhen = ""
  },
  steps = [
    Command.Config::{
      command = [
        "./.buildkite/scripts/generate-jobs.sh > src/gen/Jobs.dhall",
        triggerCommand "src/Monorepo.dhall"
      ],
      label = "Prepare monorepo triage",
      key = "monorepo",
      target = Size.Small
    }
  ]
}
in Pipeline.build config
