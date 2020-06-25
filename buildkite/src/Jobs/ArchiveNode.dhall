let Prelude = ../External/Prelude.dhall
let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall
let Command = ../Command/Base.dhall
let OpamInit = ../Command/OpamInit.dhall
let Libp2pHelper = ../Command/Libp2pHelperBuild.dhall
let Docker = ../Command/Docker/Type.dhall
let Size = ../Command/Size.dhall
in

Pipeline.build
  Pipeline.Config::
    { spec = JobSpec::
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
            { commands = OpamInit.andThenRunInDocker (Prelude.Text.concatSep "\n"
                [ "sudo apt-get install -y postgresql"
                , "PGPASSWORD=codarules psql -h localhost -p 5432 -U admin -d archiver -a -f src/app/archive/create_schema.sql"
                , "./scripts/test.py run "test_archive_processor:coda-archive-processor-test"
                ])
            , label = "Archive-node unit tests"
            , key = "build-client-sdk"
            , target = Size.Large
            , docker = None Docker.Type
            }
      ]
    }