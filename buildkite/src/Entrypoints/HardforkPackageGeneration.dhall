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

let config : Pipeline.Config.Type = Pipeline.Config::{
  spec = JobSpec::{
    name = "prepare hardfork package generation",
    dirtyWhen = [ SelectFiles.everything ]
  },
  steps = [
    Command.build Command.Config::{
      commands = [
        Cmd.run "./buildkite/scripts/generate-jobs.sh > buildkite/src/gen/Jobs.dhall",
        Cmd.quietly "dhall-to-yaml --quoted <<< '(./buildkite/src/Jobs/MinaArtifactHardforkBullseye.dhall)  | buildkite-agent pipeline upload"
        Cmd.quietly "dhall-to-yaml --quoted <<< '(./buildkite/src/Jobs/MinaArtifactHardforkBuster.dhall)  | buildkite-agent pipeline upload"
        Cmd.quietly "dhall-to-yaml --quoted <<< '(./buildkite/src/Jobs/MinaArtifactHardforkFocal.dhall) | buildkite-agent pipeline upload"
      ],
      label = "Prepare Hardfork Package Generation",
      key = "prepare-hardfork-package-genearation",
      target = Size.Small,
      docker = Some Docker::{
        image = (./Constants/ContainerImages.dhall).toolchainBase,
        environment = ["BUILDKITE_AGENT_ACCESS_TOKEN"]
      }
    }
  ]
}
in (Pipeline.build config).pipeline
