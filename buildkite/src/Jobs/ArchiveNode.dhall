let Prelude = ../External/Prelude.dhall
let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall
let Command = ../Command/Base.dhall
let OpamInit = ../Command/OpamInit.dhall
let Docker = ../Command/Docker/Type.dhall
let Size = ../Command/Size.dhall
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
          , S.strictlyStart (S.contains "buildkite/src/Jobs/ArchiveNode")
          ]
        , name = "ArchiveNode"
        }
    , steps =
      [ Command.build
          Command.Config::
            { commands =
              OpamInit.andThenRunInDocker
                [ "POSTGRES_PASSWORD=${password}"
                , "POSTGRES_USER=${user}"
                , "POSTGRES_DB=${db}"
                ]
                (Prelude.Text.concatSep " && "
                  [ "bash buildkite/scripts/setup-database-for-archive-node.sh ${user} ${password} ${db}"
                  , "PGPASSWORD=${password} psql -h localhost -p 5432 -U ${user} -d ${db} -a -f src/app/archive/create_schema.sql"
                  , "LIBP2P_NIXLESS=1 GO=/usr/lib/go/bin/go make libp2p_helper"
                  , "./scripts/test.py run --non-interactive --collect-artifacts --yes --output-dir '/var/buildkite/test_output' 'test_archive_processor:coda-archive-processor-test'"
                  ])
            , label = "Archive-node unit tests"
            , key = "build-client-sdk"
            , target = Size.Large
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "/var/buildkite/test_output" ]
            }
      ]
    }