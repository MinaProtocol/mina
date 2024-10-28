let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let dependsOn =
      [ { name = "MinaArtifactBullseye"
        , key = "daemon-devnet-bullseye-docker-image"
        }
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/check-compatibility" "sh"
          , S.exactly "buildkite/src/Jobs/Test/DevelopCompatibility" "dhall"
          ]
        , path = "Test"
        , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
        , name = "DevelopCompatibility"
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "buildkite/scripts/check-compatibility.sh develop" ]
            , label = "Test: develop compatibilty test"
            , key = "develop-compatibilty-test"
            , target = Size.XLarge
            , docker = None Docker.Type
            , depends_on = dependsOn
            , timeout_in_minutes = Some +60
            }
        ]
      }
