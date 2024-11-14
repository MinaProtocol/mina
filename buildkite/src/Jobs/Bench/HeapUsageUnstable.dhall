let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let name = "HeapUsageUnstable"

let bench = "heap-usage"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , path = "Bench"
          , name = name
          , label = "Heap Usage"
          , key = bench
          , bench = bench
          , yellowThreshold = 0.1
          , redThreshold = 0.3
          }
      )
