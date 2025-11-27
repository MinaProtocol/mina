let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Profile = ../../Constants/Profiles.dhall

let Mesa = ../../Lib/Mesa.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Mainnet
          , profile = Profile.Type.Mainnet
          , timeout = 2400
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          , excludeIf = [ Mesa.forMesa ]
          }
      )
