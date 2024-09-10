let Prelude = ../../External/Prelude.dhall

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

let db = "archiver"

let command_key = "archive-unit-tests"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Test/ArchiveNodeUnitTest")
          ]
        , path = "Test"
        , name = "ArchiveNodeUnitTest"
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
                RunInToolchain.runInToolchain
                  [ "POSTGRES_PASSWORD=${password}"
                  , "POSTGRES_USER=${user}"
                  , "POSTGRES_DB=${db}"
                  , "MINA_TEST_POSTGRES=postgres://${user}:${password}@localhost:5434/${db}"
                  , "GO=/usr/lib/go/bin/go"
                  , "DUNE_INSTRUMENT_WITH=bisect_ppx"
                  , "COVERALLS_TOKEN"
                  ]
                  ( Prelude.Text.concatSep
                      " && "
                      [ "bash buildkite/scripts/setup-database-for-archive-node.sh ${user} ${password} ${db}"
                      , WithCargo.withCargo
                          "eval \\\$(opam config env) && dune runtest src/app/archive && buildkite/scripts/upload-partial-coverage-data.sh ${command_key} dev"
                      ]
                  )
            , label = "Archive node unit tests"
            , key = command_key
            , target = Size.Large
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            }
        ]
      }
