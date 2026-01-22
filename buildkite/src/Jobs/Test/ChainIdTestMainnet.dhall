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
      "6bc1d75e39f3bbe2bd0418160775c6655d5854c1121dc5044c70e4481e4476c0"

in  ChainIdTest.makeTest
      "ChainIdTestMainnet"
      scopes
      deps
      network
      expectedChainId
