let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let Size = ../../Command/Size.dhall

let S = ../../Lib/SelectFiles.dhall

let name = "MinaBaseUnstable"

let bench = "mina-base"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , path = "Bench"
          , name = name
          , label = "Mina Base Pr"
          , additionalDirtyWhen =
            [ S.exactly "buildkite/src/Jobs/Bench/${name}" "dhall" ]
          , size = Size.Small
          , bench = bench
          , key = bench
          , yellowThreshold = 0.1
          , redThreshold = 0.3
          }
      )
