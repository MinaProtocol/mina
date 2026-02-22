let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let name = "MinaBaseStable"

let bench = "mina-base"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , scope = PipelineScope.AllButPullRequest
          , path = "Bench"
          , name = name
          , label = "Mina Base"
          , key = bench
          , bench = bench
          }
      )
