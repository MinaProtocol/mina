let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DepsSpec::{ build_flag = BuildFlags.Type.Instrumented }

let key = "archive-hardfork-toolbox-test"

let debs = "mina-archive-devnet-instrumented"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/archive_hardfork_toolbox")
          , S.exactly
              "buildkite/src/Jobs/Test/ArchiveHardforkToolboxTest"
              "dhall"
          , S.exactly
              "scripts/tests/archive-hardfork-toolbox/hf_archive"
              "tar.gz"
          , S.exactly "scripts/tests/archive-hardfork-toolbox/runner" "sh"
          ]
        , path = "Test"
        , name = "ArchiveHardforkToolboxTest"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Archive
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ RunWithPostgres.runInToolchainWithPostgresAndDebs
                  ([] : List Text)
                  ( Some
                      ( RunWithPostgres.ScriptOrArchive.Archive
                          { Script = "post_upgrade_archive.sql"
                          , Archive =
                              "scripts/tests/archive-hardfork-toolbox/post_upgrade_archive.tar.gz"
                          }
                      )
                  )
                  ContainerImages.minaToolchainBullseye.amd64
                  debs
                  (     "scripts/tests/archive-hardfork-toolbox/runner.sh --mode pre-fork"
                    ++  " && scripts/tests/archive-hardfork-toolbox/runner.sh --mode upgrade"
                  )
              , Cmd.run
                  "buildkite/scripts/upload-partial-coverage-data.sh ${key}"
              , RunWithPostgres.runInToolchainWithPostgresAndDebs
                  ([] : List Text)
                  ( Some
                      ( RunWithPostgres.ScriptOrArchive.Archive
                          { Script = "hf_archive.sql"
                          , Archive =
                              "scripts/tests/archive-hardfork-toolbox/hf_archive.tar.gz"
                          }
                      )
                  )
                  ContainerImages.minaToolchainBullseye.amd64
                  debs
                  "scripts/tests/archive-hardfork-toolbox/runner.sh --mode post-fork"
              , Cmd.run
                  "buildkite/scripts/upload-partial-coverage-data.sh ${key}"
              ]
            , label = "Archive: Hardfork Toolbox Test"
            , key = key
            , target = Size.Large
            , depends_on = dependsOn
            }
        ]
      }
