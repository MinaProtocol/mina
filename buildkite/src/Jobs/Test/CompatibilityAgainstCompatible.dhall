let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Size = ../../Command/Size.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.Type.Bullseye
        (Some Network.Type.Devnet)
        Profiles.Type.Standard
        Artifacts.Type.Daemon

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/tests/cross-compatibility.sh" "sh"
          , S.exactly
              "buildkite/src/Jobs/Test/CompatibilityAgainsCompatible"
              "dhall"
          ]
        , path = "Test"
        , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
        , name = "CompatibilityAgainstCompatible"
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "buildkite/scripts/tests/cross-compatibility.sh compatible"
              ]
            , label = "Test: compatible compatibilty test"
            , key = "develop-compatibilty-test"
            , target = Size.XLarge
            , docker = None Docker.Type
            , depends_on = dependsOn
            , soft_fail = Some (B/SoftFail.Boolean True)
            , timeout_in_minutes = Some +60
            }
        ]
      }
