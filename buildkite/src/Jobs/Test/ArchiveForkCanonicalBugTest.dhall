let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let WithCargo = ../../Command/WithCargo.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let user = "admin"

let password = "codarules"

let host_port = "localhost:5432"

let command_key = "archive-fork-canonical-bug-test"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/app/archive")
          , S.strictlyStart (S.contains "src/test/archive")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/ArchiveForkCanonicalBugTest")
          , S.exactly
              "buildkite/scripts/tests/archive-fork-canonical-bug-test"
              "sh"
          ]
        , path = "Test"
        , name = "ArchiveForkCanonicalBugTest"
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
                RunInToolchain.runInToolchain
                  [ "POSTGRES_PASSWORD=${password}"
                  , "POSTGRES_USER=${user}"
                  , "GO=/usr/lib/go/bin/go"
                  ]
                  ( WithCargo.withCargo
                      "./buildkite/scripts/tests/archive-fork-canonical-bug-test.sh ${user} ${password} ${host_port}"
                  )
            , label =
                "Archive fork-canonical-block bug repro (update_chain_status branch 2)"
            , key = command_key
            , target = Size.Large
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            }
        ]
      }
