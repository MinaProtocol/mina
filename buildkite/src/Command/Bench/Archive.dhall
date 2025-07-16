let BenchBase = ../../Command/Bench/Base.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let Cmd = ../../Lib/Cmds.dhall

let makeArchiveBench =
          \(name : Text)
      ->  \(mode : PipelineMode.Type)
      ->  Pipeline.build
            ( BenchBase.pipeline
                BenchBase.Spec::{
                , additionalDirtyWhen =
                  [ SelectFiles.strictlyStart
                      (SelectFiles.contains "src/test/archive")
                  , SelectFiles.exactly
                      "buildkite/src/Jobs/Bench/ArchiveStable"
                      "dhall"
                  , SelectFiles.exactly
                      "buildkite/src/Jobs/Bench/ArchiveUnstable"
                      "dhall"
                  ]
                , path = "Bench"
                , name = name
                , label = "Archive"
                , key = "archive-perf"
                , bench = "archive"
                , dependsOn =
                  [ { name = "ArchiveNodeTest", key = "archive-node-test" } ]
                , preCommands =
                  [ Cmd.run
                      "./buildkite/scripts/cache/manager.sh read archive-node-test/archive.perf ."
                  ]
                , mode = mode
                }
            )

in  { makeArchiveBench = makeArchiveBench }
