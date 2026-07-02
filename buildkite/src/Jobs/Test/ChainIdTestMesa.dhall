let Dockers = ../../Constants/Docker/Versions.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let ChainIdTest = ../../Command/ChainIdTest.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let scopes = [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]

let network = Network.Type.Mesa

let deps =
      Dockers.dependsOn
        Dockers.DepsSpec::{ network = network, profile = Profile.Type.Devnet }

let expectedChainId =
      "c0b179da879e26cfd2aa118282ca148d2eaa0a13041c789bcac5a92c7dccf6ce"

in  ChainIdTest.makeTest "ChainIdTestMesa" scopes deps network expectedChainId
