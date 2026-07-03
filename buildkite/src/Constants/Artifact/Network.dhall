let Prelude = ../../External/Prelude.dhall

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

let debianSuffix =
          \(network : Network)
      ->  merge { Devnet = "devnet", Mainnet = "mainnet" } network

let peerListUrl =
          \(network : Network)
      ->  merge
            { Devnet =
                "https://storage.googleapis.com/seed-lists/devnet_seeds.txt"
            , Mainnet =
                "https://storage.googleapis.com/seed-lists/mainnet_seeds.txt"
            }
            network

let toLabelSegment = \(network : Network) -> "-${debianSuffix network}"

let requiresMainnetBuild =
      \(network : Network) -> merge { Devnet = False, Mainnet = True } network

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
    , debianSuffix = debianSuffix
    , peerListUrl = peerListUrl
    , toLabelSegment = toLabelSegment
    , requiresMainnetBuild = requiresMainnetBuild
    , foldMinaBuildMainnetEnv = foldMinaBuildMainnetEnv
    , buildMainnetEnv = buildMainnetEnv
    }
