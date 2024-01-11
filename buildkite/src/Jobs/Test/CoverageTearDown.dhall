let Prelude =  ../../External/Prelude.dhall
let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

in Pipeline.build 
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [ S.everything ],
        path = "Test",
        tags = [ PipelineTag.Type.TearDown ],
        name = "CoverageTearDown"
    }
  , steps = [
      Command.build
        Command.Config::{
          commands =
            RunInToolchain.runInToolchainBullseye ["COVERALLS_TOKEN"]
              "buildkite/scripts/finish-coverage-data-upload.sh",
          label = "Finish coverage data gathering",
          key = "finish-coverage-data",
          target = Size.Small
        }
    ]
  }