let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let name = "SnarkProfilerStable"

let bench = "snark"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , scope = PipelineScope.AllButPullRequest
          , path = "Bench"
          , name = name
          , label = "Snark Profiler"
          , key = bench
          , bench = bench
          }
      )
