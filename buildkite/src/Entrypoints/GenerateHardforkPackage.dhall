-- Autogenerates any pre-reqs for monorepo triage execution
-- Keep these rules lean! They have to run unconditionally.

let SelectFiles = ../Lib/SelectFiles.dhall
let Cmd = ../Lib/Cmds.dhall

let Command = ../Command/Base.dhall
let Docker = ../Command/Docker/Type.dhall
let JobSpec = ../Pipeline/JobSpec.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let PipelineMode = ../Pipeline/Mode.dhall
let PipelineFilter = ../Pipeline/Filter.dhall
let PipelineTag = ../Pipeline/Tag.dhall
let Size = ../Command/Size.dhall
let triggerCommand = ../Pipeline/TriggerCommand.dhall


let B = ../External/Buildkite.dhall
let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let HardforkPackageGeneration = ../Command/HardforkPackageGeneration.dhall
let Package =  ../Constants/DebianPackage.dhall
let Profile =  ../Constants/Profiles.dhall
let Network = ../Constants/Network.dhall
let DebianVersions = ../Constants/DebianVersions.dhall

let generate_hardfork_package = \(spec : HardforkPackageGeneration.Spec.Type) ->

  let config : Pipeline.Config.Type = Pipeline.Config::{
    spec = JobSpec::{
      name = "generate",
      dirtyWhen = [ SelectFiles.everything ]
    },
    steps = [
      Command.build Command.Config::{
        commands = [
          Cmd.run "./buildkite/scripts/generate-jobs.sh > buildkite/src/gen/Jobs.dhall",
          Cmd.quietly "dhall-to-yaml --quoted <<< '(Pipeline.build (HardforkPackageGeneration.pipeline HardforkPackageGeneration.Spec::{=}).pipeline' | buildkite-agent pipeline upload",
          Cmd.quietly "dhall-to-yaml --quoted <<< '(Pipeline.build (HardforkPackageGeneration.pipeline HardforkPackageGeneration.Spec::{codename = DebianVersions.DebVersion.Buster}).pipeline' | buildkite-agent pipeline upload"
        ],
        label = "Generate hardfork package",
        key = "generate-hardfork-package",
        target = Size.Small,
        docker = Some Docker::{
          image = (../Constants/ContainerImages.dhall).toolchainBase,
          environment = ["BUILDKITE_AGENT_ACCESS_TOKEN"]
        }
      }
    ]
  }
  in (Pipeline.build config).pipeline


in {
  generate_hardfork_package = generate_hardfork_package
}