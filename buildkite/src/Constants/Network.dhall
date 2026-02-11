let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | TestnetGeneric | PreMesa1 | Mesa >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , TestnetGeneric = "TestnetGeneric"
            , PreMesa1 = "PreMesa1"
            , Mesa = "Mesa"
            }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , TestnetGeneric = "testnet_generic"
            , PreMesa1 = "hetzner-pre-mesa-1"
            , Mesa = "mesa"
            }
            network

let debianSuffix =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , TestnetGeneric = "testnet-generic"
            , PreMesa1 = "hetzner-pre-mesa-1"
            , Mesa = "mesa"
            }
            network

let requiresMainnetBuild =
          \(network : Network)
      ->  merge
            { Devnet = True
            , Mainnet = True
            , TestnetGeneric = True
            , PreMesa1 = False
            , Mesa = False
            }
            network

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
    , requiresMainnetBuild = requiresMainnetBuild
    , foldMinaBuildMainnetEnv = foldMinaBuildMainnetEnv
    , buildMainnetEnv = buildMainnetEnv
    }
