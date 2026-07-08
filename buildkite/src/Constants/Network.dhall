let Prelude = ../External/Prelude.dhall

let List/any = Prelude.List.any

let Network
    : Type
    = < Devnet | Mainnet | MesaMut | MesaPreflight >

let capitalName =
          \(network : Network)
      ->  merge
            { Devnet = "Devnet"
            , Mainnet = "Mainnet"
            , MesaMut = "MesaMut"
            , MesaPreflight = "MesaPreflight"
            }
            network

let lowerName =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , MesaMut = "mesa-mut"
            , MesaPreflight = "mesa-preflight"
            }
            network

let debianSuffix =
          \(network : Network)
      ->  merge
            { Devnet = "devnet"
            , Mainnet = "mainnet"
            , MesaMut = "mesa-mut"
            , MesaPreflight = "mesa-preflight"
            }
            network

let peerListUrl =
          \(network : Network)
      ->  merge
            { Devnet =
                "https://storage.googleapis.com/seed-lists/devnet_seeds.txt"
            , Mainnet =
                "https://storage.googleapis.com/seed-lists/mainnet_seeds.txt"
            , MesaMut =
                "https://storage.googleapis.com/gs://o1labs-gitops-infrastructure/mina-mesa-mut/mina-mesa-mut-peer-list-url.txt"
            , MesaPreflight =
                "https://storage.googleapis.com/o1labs-gitops-infrastructure/mina-mesa-network/mina-mesa-network-seeds.txt"
            }
            network

let toLabelSegment = \(network : Network) -> "-${debianSuffix network}"

let requiresMainnetBuild =
          \(network : Network)
      ->  merge
            { Devnet = False
            , Mainnet = True
            , MesaMut = False
            , MesaPreflight = False
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
    , peerListUrl = peerListUrl
    , toLabelSegment = toLabelSegment
    , requiresMainnetBuild = requiresMainnetBuild
    , foldMinaBuildMainnetEnv = foldMinaBuildMainnetEnv
    , buildMainnetEnv = buildMainnetEnv
    }
