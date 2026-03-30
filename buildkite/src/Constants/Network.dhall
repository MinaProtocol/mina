let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | PreMesa1 >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet", Mainnet = "Mainnet", PreMesa1 = "PreMesa1" }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , PreMesa1 = "hetzner-pre-mesa-1"
            }
            network

let debianSuffix =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , PreMesa1 = "hetzner-pre-mesa-1"
            }
            network

let toLabelSegment = \(network : Network) -> "-${debianSuffix network}"

let requiresMainnetBuild =
          \(network : Network)
      ->  merge { Devnet = False, Mainnet = True, PreMesa1 = False } network

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
    , toLabelSegment = toLabelSegment
    , requiresMainnetBuild = requiresMainnetBuild
    , foldMinaBuildMainnetEnv = foldMinaBuildMainnetEnv
    , buildMainnetEnv = buildMainnetEnv
    }
