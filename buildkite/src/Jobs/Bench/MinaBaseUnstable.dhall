let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let Size = ../../Command/Size.dhall

let name = "MinaBaseUnstable"

let bench = "mina-base"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , path = "Bench"
          , name
          , label = "Mina Base"
          , size = Size.Small
          , bench
          , key = bench
          , yellowThreshold = 0.1
          , redThreshold = 0.3
          }
      )
