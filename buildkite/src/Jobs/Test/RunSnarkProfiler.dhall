let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Docker = ../../Command/Docker/Type.dhall

let Network = ../../Constants/Network.dhall

let Size = ../../Command/Size.dhall

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DebVersion.Bullseye
        Network.Type.Devnet
        Profiles.Type.Standard

let buildTestCmd
    : Size -> List Command.TaggedKey.Type -> Command.Type
    =     \(cmd_target : Size)
      ->  \(dependsOn : List Command.TaggedKey.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "buildkite/scripts/bench/snark_transaction_profiler.sh"
            , label = "Snark Transaction Profiler"
            , key = "snark-transaction-profiler"
            , target = cmd_target
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "core_dumps/*" ]
            , depends_on = dependsOn
            }

in  Pipeline.build
      Pipeline.Config::{
      , spec =
          let lintDirtyWhen =
                [ S.strictlyStart (S.contains "src")
                , S.exactly "buildkite/src/Jobs/Test/RunSnarkProfiler" "dhall"
                , S.exactly
                    "buildkite/scripts/bench/snark_transaction_profiler"
                    "sh"
                , S.strictlyStart (S.contains "scripts/benchmarks")
                ]

          in  JobSpec::{
              , dirtyWhen = lintDirtyWhen
              , path = "Test"
              , name = "RunSnarkProfiler"
              , tags =
                [ PipelineTag.Type.Long
                , PipelineTag.Type.Test
                , PipelineTag.Type.Stable
                ]
              }
      , steps = [ buildTestCmd Size.Small dependsOn ]
      }
