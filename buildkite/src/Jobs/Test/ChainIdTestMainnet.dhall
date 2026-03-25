let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let ChainIdTest = ../../Command/ChainIdTest.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let scopes = [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]

let network = Network.Type.Mainnet

let deps =
      Dockers.dependsOn
        Dockers.DepsSpec::{ network = network, profile = Profile.Type.Mainnet }

let expectedChainId =
      "a7351abc7ddf2ea92d1b38cc8e636c271c1dfd2c081c637f62ebc2af34eb7cc1"

in  ChainIdTest.makeTest
      "ChainIdTestMainnet"
      scopes
      deps
      network
      expectedChainId
