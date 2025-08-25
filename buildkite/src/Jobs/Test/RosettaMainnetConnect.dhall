let Pipeline = ../../Pipeline/Dsl.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

let Profile = ../../Constants/Profiles.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{
          , network = Network.Type.Mainnet
          , profile = Profile.Type.Mainnet
          , timeout = 2400
          }
      )
