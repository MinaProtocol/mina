let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let Size = ../../Command/Size.dhall

let S = ../../Lib/SelectFiles.dhall

let name = "ZkappLimitsUnstable"

let bench = "zkapp"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , path = "Bench"
          , name = name
          , label = "Zkapp Limits Pr"
          , additionalDirtyWhen =
            [ S.exactly "buildkite/src/Jobs/Bench/${bench}" "dhall" ]
          , size = Size.Small
          , key = bench
          , bench = bench
          , yellowThreshold = 0.1
          , redThreshold = 0.3
          }
      )
