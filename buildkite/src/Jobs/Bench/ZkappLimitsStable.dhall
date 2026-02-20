let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let name = "ZkappLimitsStable"

let bench = "zkapp"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , scope = PipelineScope.AllButPullRequest
          , path = "Bench"
          , name = name
          , label = "Zkapp Limits"
          , key = bench
          , bench = bench
          }
      )
