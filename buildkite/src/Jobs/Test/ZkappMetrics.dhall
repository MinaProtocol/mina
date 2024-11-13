let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let dependsOn =
      DebianVersions.dependsOn
        DebianVersions.DebVersion.Bullseye
        Profiles.Type.Standard

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "buildkite/src/Jobs/Test/ZkappMetrics")
          , S.strictlyStart (S.contains "src")
          , S.exactly "buildkite/scripts/bench/zkapp_metrics" "sh"
          , S.strictlyStart (S.contains "scripts/benchmarks")
          ]
        , path = "Test"
        , name = "ZkappMetrics"
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
                  ([] : List Text)
                  "./buildkite/scripts/bench/zkapp_metrics.sh"
            , label = "Zkapp Metrics"
            , key = "zkapp-metrics"
            , target = Size.Medium
            , docker = None Docker.Type
            , depends_on = dependsOn
            }
        ]
      }
