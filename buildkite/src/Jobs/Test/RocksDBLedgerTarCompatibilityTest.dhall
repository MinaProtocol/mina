let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let Docker = ../../Command/Docker/Type.dhall

let commands =
      [ Cmd.run
          "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --quiet --yes python3 python3-pip build-essential sudo curl"
      , Cmd.run "./scripts/rocksdb-compatibility/install-rocksdb.sh"
      , Cmd.run
          "pip3 install --break-system-packages -r ./scripts/rocksdb-compatibility/requirements.txt"
      , Cmd.run "python3 ./scripts/rocksdb-compatibility/test.py"
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "scripts/rocksdb-compatibility")
          , S.exactly
              "buildkite/src/Jobs/Test/RocksDBLedgerTarCompatibilityTest"
              "dhall"
          ]
        , path = "Test"
        , name = "RocksDBLedgerTarCompatibilityTest"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = commands
            , label = "Check RocksDB Ledger Tar Compatibility"
            , key = "test"
            , target = Size.Multi
            , docker = Some Docker::{ image = "ubuntu:noble" }
            }
        ]
      }
