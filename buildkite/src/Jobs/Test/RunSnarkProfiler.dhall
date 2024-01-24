let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall
let Profiles = ../../Constants/Profiles.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall


let dependsOn = DebianVersions.dependsOn DebianVersions.DebVersion.Bullseye Profiles.Type.Standard

in 

let buildTestCmd : Size -> List Command.TaggedKey.Type -> Command.Type = \(cmd_target : Size) -> \(dependsOn : List Command.TaggedKey.Type) ->
  Command.build
    Command.Config::{
      commands = [
        Cmd.runInDocker
            Cmd.Docker::{
              image = (../../Constants/ContainerImages.dhall).ubuntu2004
            }
            "buildkite/scripts/run-snark-transaction-profiler.sh"
      ],
      label = "Snark Transaction Profiler",
      key = "snark-transaction-profiler",
      target = cmd_target,
      docker = None Docker.Type,
      artifact_paths = [ S.contains "core_dumps/*" ],
      depends_on = dependsOn
    }

in

Pipeline.build
  Pipeline.Config::{
    spec =
      let lintDirtyWhen = [
        S.strictlyStart (S.contains "src/lib"),
        S.exactly "buildkite/src/Jobs/Test/RunSnarkProfiler" "dhall",
        S.exactly "buildkite/scripts/run-snark-transaction-profiler" "sh",
        S.exactly "scripts/snark_transaction_profiler" "py"
      ]

      in

      JobSpec::{
        dirtyWhen = lintDirtyWhen,
        path = "Test",
        name = "RunSnarkProfiler",
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
      },
    steps = [
      buildTestCmd Size.Small dependsOn
    ]
  }
