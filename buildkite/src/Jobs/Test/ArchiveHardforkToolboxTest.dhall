let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , buildFlags = BuildFlags.Type.Instrumented
        , artifact = Artifacts.Type.FunctionalTestSuite
        }

let key = "archive-hardfork-toolbox-test"

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
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ RunWithPostgres.runInDockerWithPostgresConn
                  ([] : List Text)
                  ( RunWithPostgres.ScriptOrArchive.Archive
                      { Script = "post_upgrade_archive.sql"
                      , Archive =
                          "scripts/tests/archive-hardfork-toolbox/post_upgrade_archive.tar.gz"
                      }
                  )
                  ( Artifacts.fullDockerTag
                      Artifacts.Tag::{
                      , artifact = Artifacts.Type.FunctionalTestSuite
                      , buildFlags = BuildFlags.Type.Instrumented
                      }
                  )
                  (     "scripts/tests/archive-hardfork-toolbox/runner.sh --mode pre-fork"
                    ++  " && scripts/tests/archive-hardfork-toolbox/runner.sh --mode upgrade"
                    ++  " && buildkite/scripts/upload-partial-coverage-data.sh ${key} "
                  )
              , RunWithPostgres.runInDockerWithPostgresConn
                  ([] : List Text)
                  ( RunWithPostgres.ScriptOrArchive.Archive
                      { Script = "hf_archive.sql"
                      , Archive =
                          "scripts/tests/archive-hardfork-toolbox/hf_archive.tar.gz"
                      }
                  )
                  ( Artifacts.fullDockerTag
                      Artifacts.Tag::{
                      , artifact = Artifacts.Type.FunctionalTestSuite
                      , buildFlags = BuildFlags.Type.Instrumented
                      }
                  )
                  "scripts/tests/archive-hardfork-toolbox/runner.sh --mode post-fork && buildkite/scripts/upload-partial-coverage-data.sh ${key} "
              ]
            , label = "Archive: Hardfork Toolbox Test"
            , key = key
            , target = Size.Large
            , depends_on = dependsOn
            }
        ]
      }
