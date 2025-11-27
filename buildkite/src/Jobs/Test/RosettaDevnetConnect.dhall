let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Mesa = ../../Lib/Mesa.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Devnet
          , scope = PipelineScope.AllButPullRequest
          , excludeIf = [ Mesa.forMesa ]
          }
      )
