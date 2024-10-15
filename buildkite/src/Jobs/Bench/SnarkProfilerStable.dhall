let BenchBase = ../../Command/Bench/Base.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let S = ../../Lib/SelectFiles.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let name = "SnarkProfilerStable"

let bench = "snark"

in  Pipeline.build
      ( BenchBase.pipeline
          BenchBase.Spec::{
          , mode = PipelineMode.Type.Stable
          , path = "Bench"
          , name = name
          , label = "Snark Profiler Stable"
          , additionalDirtyWhen =
            [ S.exactly "buildkite/src/Jobs/Bench/${name}" "dhall" ]
          , key = bench
          , bench = bench
          }
      )
