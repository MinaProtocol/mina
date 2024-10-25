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
      ->  merge { Devnet = False, Mainnet = True, Berkeley = False } network

let buildMainnetEnv =
          \(network : Network)
      ->        if requiresMainnetBuild network

          then  "MINA_BUILD_MAINNET=true"

          else  "MINA_BUILD_MAINNET=false"

in  { Type = Network
    , capitalName = capitalName
    , lowerName = lowerName
    , requiresMainnetBuild = requiresMainnetBuild
    , buildMainnetEnv = buildMainnetEnv
    }
