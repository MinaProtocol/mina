let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let Size = ../../Command/Size.dhall

let name = "SnarkProfilerUnstable"

let bench = "snark"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , path = "Bench"
          , name = name
          , label = "Snark Profiler"
          , size = Size.Small
          , bench = bench
          , key = bench
          , yellowThreshold = 0.1
          , redThreshold = 0.3
          }
      )
