let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let Size = ../../Command/Size.dhall

let name = "PersistentFrontierUnstable"

let bench = "persistent-frontier"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , path = "Bench"
          , name = name
          , label = "Peristent Frontier"
          , size = Size.Small
          , key = bench
          , bench = bench
          , yellowThreshold = 0.1
          , redThreshold = 0.3
          }
      )
