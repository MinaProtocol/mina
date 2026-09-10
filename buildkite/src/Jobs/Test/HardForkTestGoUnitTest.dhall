let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/hardfork_test")
          , S.exactly "buildkite/src/Jobs/Test/HardForkTestGoUnitTest" "dhall"
          ]
        , path = "Test"
        , name = "HardForkTestGoUnitTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image = ContainerImages.minaToolchain
                  , extraEnv = [ "GO=/usr/lib/go/bin/go" ]
                  }
                  "make -C src/app/hardfork_test test"
              ]
            , label = "hardfork_test Go unit tests"
            , key = "hardfork-test-go-unit-test"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
