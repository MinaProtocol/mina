let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Profile = ../../Constants/Profiles.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Mainnet
          , timeout = 2400
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
