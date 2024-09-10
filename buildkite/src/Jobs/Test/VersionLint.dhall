let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.Type.Bullseye
        Network.Type.Devnet
        Profiles.Type.Standard
        Artifacts.Type.Daemon

let buildTestCmd
    : Text -> Size -> List Command.TaggedKey.Type -> Command.Type
    =     \(release_branch : Text)
      ->  \(cmd_target : Size)
      ->  \(dependsOn : List Command.TaggedKey.Type)
      ->  Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image =
                      ( ../../Constants/ContainerImages.dhall
                      ).minaToolchainBullseye
                  }
                  "buildkite/scripts/dump-mina-type-shapes.sh"
              , Cmd.runInDocker
                  Cmd.Docker::{
                  , image =
                      ( ../../Constants/ContainerImages.dhall
                      ).minaToolchainBullseye
                  }
                  "buildkite/scripts/version-linter-patch-missing-type-shapes.sh ${release_branch}"
              , Cmd.run
                  "gsutil cp *-type_shape.txt \$MINA_TYPE_SHAPE gs://mina-type-shapes"
              , Cmd.runInDocker
                  Cmd.Docker::{
                  , image =
                      ( ../../Constants/ContainerImages.dhall
                      ).minaToolchainBullseye
                  }
                  "buildkite/scripts/version-linter.sh ${release_branch}"
              ]
            , label = "Versioned type linter"
            , key = "version-linter"
            , target = cmd_target
            , docker = None Docker.Type
            , depends_on = dependsOn
            , artifact_paths = [ S.contains "core_dumps/*" ]
            }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let lintDirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.exactly "buildkite/src/Jobs/Test/VersionLint" "dhall"
                , S.exactly "buildkite/scripts/version-linter" "sh"
                ]

          in  JobSpec::{
              , dirtyWhen = lintDirtyWhen
              , path = "Test"
              , name = "VersionLint"
              , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
              }
      , steps = [ buildTestCmd "develop" Size.Small dependsOn ]
      }
