let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet >

let capitalName =
          \(network : Network)
      ->  merge { Devnet = "Devnet", Mainnet = "Mainnet" } network

let lowerName =
          \(network : Network)
      ->  merge { Devnet = "devnet", Mainnet = "mainnet" } network

let requiresMainnetBuild =
      \(network : Network) -> merge { Devnet = False, Mainnet = True } network

let foldMinaBuildMainnetEnv =
          \(networks : List Network)
      ->        if List/any Network requiresMainnetBuild networks

          then  "MINA_BUILD_MAINNET=true"

          else  "MINA_BUILD_MAINNET=false"

in  { Type = Network
    , capitalName = capitalName
    , lowerName = lowerName
    , requiresMainnetBuild = requiresMainnetBuild
    , foldMinaBuildMainnetEnv = foldMinaBuildMainnetEnv
    }
