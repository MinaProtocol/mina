let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let name = "HeapUsageStable"

let bench = "heap-usage"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , scope = PipelineScope.AllButPullRequest
          , path = "Bench"
          , name = name
          , label = "Heap Usage"
          , key = bench
          , bench = bench
          }
      )
