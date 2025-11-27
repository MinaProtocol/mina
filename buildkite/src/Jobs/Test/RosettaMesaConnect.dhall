let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let Mesa = ../../Lib/Mesa.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Mesa
          , scope = PipelineScope.AllButPullRequest
          , dockerType = Dockers.Type.Bookworm
          , profile = Profiles.Type.Devnet
          , includeIf = [ Mesa.forMesa ]
          }
      )
