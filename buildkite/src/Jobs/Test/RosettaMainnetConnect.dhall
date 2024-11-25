let Pipeline = ../../Pipeline/Dsl.dhall

let Network = ../../Constants/Network.dhall

let Connectivity = ../../Command/Rosetta/Connectivity.dhall

in  Pipeline.build
      ( Connectivity.pipeline
          Connectivity.Spec::{ network = Network.Type.Mainnet, timeout = 2400 }
      )
