let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let S = ../../Lib/SelectFiles.dhall

let name = "MinaBaseStable"

let bench = "mina-base"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , mode = PipelineMode.Type.Stable
          , path = "Bench"
          , name = name
          , label = "Mina Base Stable"
          , additionalDirtyWhen =
            [ S.exactly "buildkite/src/Jobs/Bench/${name}" "dhall" ]
          , key = bench
          , bench = bench
          }
      )
