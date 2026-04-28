let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | PreMesa1 | Mesa >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , PreMesa1 = "PreMesa1"
            , Mesa = "Mesa"
            }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , PreMesa1 = "hetzner-pre-mesa-1"
            , Mesa = "mesa"
            }
            network

let debianSuffix =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , PreMesa1 = "hetzner-pre-mesa-1"
            , Mesa = "mesa"
            }
            network

let peerListUrl =
          \(network : Network)
      ->  merge
            { Devnet =
                "https://storage.googleapis.com/seed-lists/devnet_seeds.txt"
            , Mainnet =
                "https://storage.googleapis.com/seed-lists/mainnet_seeds.txt"
            , PreMesa1 =
                "https://storage.googleapis.com/o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt"
            , Mesa =
                "https://storage.googleapis.com/o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt"
            }
            network

let toLabelSegment = \(network : Network) -> "-${debianSuffix network}"

let requiresMainnetBuild =
          \(network : Network)
      ->  merge
            { Devnet = False, Mainnet = True, PreMesa1 = False, Mesa = False }
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
    , peerListUrl = peerListUrl
    , toLabelSegment = toLabelSegment
    , requiresMainnetBuild = requiresMainnetBuild
    , foldMinaBuildMainnetEnv = foldMinaBuildMainnetEnv
    , buildMainnetEnv = buildMainnetEnv
    }
