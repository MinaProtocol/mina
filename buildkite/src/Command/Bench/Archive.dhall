let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let Cmd = ../../Lib/Cmds.dhall

let makeArchiveBench =
          \(name : Text)
      ->  \(mode : PipelineMode.Type)
      ->  Pipeline.build
            ( BenchBase.pipeline
                BenchBase.Spec::{
                , path = "Bench"
                , name = name
                , label = "Archive"
                , key = "archive-perf"
                , bench = "archive"
                , dependsOn =
                  [ { name = "ArchiveNodeTest", key = "archive-node-test" } ]
                , preCommands =
                  [ Cmd.run
                      "./buildkite/scripts/cache/manager.sh read archive-node-tests/archive.perf ."
                  ]
                , mode = mode
                , extraArgs =
                    if PipelineMode.isStable mode then "" else "--no-upload"
                }
            )

in  { makeArchiveBench = makeArchiveBench }
