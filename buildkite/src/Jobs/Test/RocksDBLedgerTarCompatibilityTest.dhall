let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let key = "test"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "scripts/rocksdb-compatibility")
          , S.exactly "buildkite/src/Jobs/Test/RocksDBLedgerTarCompatibilityTest" "dhall"
          ]
        , path = "Test"
        , name = "RocksDBLedgerTarCompatibilityTest"
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
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  (     "./scripts/rocksdb-compatibility/install-rocksdb.sh"
                    ++  " && pip install -r ./scripts/rocksdb-compatibility/requirements.txt"
                    ++  " && python3 ./scripts/rocksdb-compatibility/rocksdb.py"
                  )
            , label = "RocksDB: Ledger Tar Compatibility Test"
            , key = key
            , target = Size.Large
            }
        ]
      }
