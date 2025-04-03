let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | Berkeley >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet", Mainnet = "Mainnet", Berkeley = "Berkeley" }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet", Mainnet = "mainnet", Berkeley = "berkeley" }
            network

let requiresMainnetBuild =
          \(network : Network)
      ->  merge { Devnet = True, Mainnet = True, Berkeley = False } network

let buildMainnetEnv =
          \(network : Network)
      ->        if requiresMainnetBuild network

          then  "MINA_BUILD_MAINNET=true"

          else  "MINA_BUILD_MAINNET=false"

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
    , buildMainnetEnv = buildMainnetEnv
    }
