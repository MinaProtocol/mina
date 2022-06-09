let Prelude = ../../External/Prelude.dhall
let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let WithCargo = ../../Command/WithCargo.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
in

let user = "admin"
let password = "codarules"
let db = "archiver"
in

Pipeline.build
  Pipeline.Config::
    { spec =
      JobSpec::
        { dirtyWhen =
          [ S.strictlyStart (S.contains "src/lib")
          , S.strictly (S.contains "Makefile")
          , S.strictlyStart (S.contains "buildkite/src/Jobs/Test/ArchiveNodeUnitTest")
          ]
        , path = "Test"
        , name = "ArchiveNodeUnitTest"
        }
    , steps =
    let outerDir : Text =
            "/var/buildkite/builds/\\\$BUILDKITE_AGENT_NAME/\\\$BUILDKITE_ORGANIZATION_SLUG/\\\$BUILDKITE_PIPELINE_SLUG"
    in
      [ Command.build
          Command.Config::
            { commands =
              RunInToolchain.runInToolchain
                [ "POSTGRES_PASSWORD=${password}"
                , "POSTGRES_USER=${user}"
                , "POSTGRES_DB=${db}"
                , "GO=/usr/lib/go/bin/go"
                ]
                (Prelude.Text.concatSep " && "
                  [ "bash buildkite/scripts/setup-database-for-archive-node.sh ${user} ${password} ${db}"
                  , "PGPASSWORD=${password} psql -h localhost -p 5432 -U ${user} -d ${db} -a -f src/app/archive/create_schema.sql"
                  , WithCargo.withCargo "eval \\\$(opam config env) && dune runtest src/app/archive"
                  ])
            , label = "Archive node unit tests"
            , key = "archive-unit-tests"
            , target = Size.Large
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            }
      ]
    }
