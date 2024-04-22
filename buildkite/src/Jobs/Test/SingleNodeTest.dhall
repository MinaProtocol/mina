let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall


let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let DebianVersions = ../../Constants/DebianVersions.dhall
let Profiles = ../../Constants/Profiles.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall


let dependsOn =
  DebianVersions.dependsOn DebianVersions.DebVersion.Bullseye Profiles.Type.Lightnet
  # DebianVersions.dependsOn DebianVersions.DebVersion.Bullseye Profiles.Type.Standard


let buildTestCmd : Size -> Command.Type = \(cmd_target : Size) ->
  let key = "single-node-tests" in
  Command.build
    Command.Config::{
      commands = RunInToolchain.runInToolchain ["DUNE_INSTRUMENT_WITH=bisect_ppx", "COVERALLS_TOKEN"] "buildkite/scripts/single-node-tests.sh && buildkite/scripts/upload-partial-coverage-data.sh ${key}",
      label = "single-node-tests",
      key = key,
      target = cmd_target,
      docker = None Docker.Type,
      depends_on = dependsOn 
    }

in

Pipeline.build
  Pipeline.Config::{
    spec = 
      let unitDirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.strictly (S.contains "Makefile"),
        S.exactly "buildkite/src/Jobs/Test/SingleNodeTest" "dhall",
        S.exactly "buildkite/scripts/single-node-tests" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = unitDirtyWhen,
        path = "Test",
        name = "SingleNodeTest",
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
      },
    steps = [
      buildTestCmd Size.XLarge
    ]
  }
