let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let name = "LedgerExportStable"

let bench = "ledger-export"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , scope = PipelineScope.AllButPullRequest
          , path = "Bench"
          , name = name
          , label = "Ledger Export"
          , key = bench
          , bench = bench
          }
      )
