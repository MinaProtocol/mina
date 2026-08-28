let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

let List/concatMap = Prelude.List.concatMap

let Debian = ../Debian/Package.dhall

let Network = ../Network.dhall

let Profiles = ./Profiles.dhall

let Artifact
    : Type
    = < Daemon : { network : Network.Type }
      | DaemonGeneric
      | DaemonProfiled : { profile : Profiles.Type }
      | DaemonLegacyHardfork : { network : Network.Type }
      | DaemonAutoHardfork : { network : Network.Type }
      | DaemonPrefork : { network : Network.Type }
      | DaemonPostfork : { network : Network.Type }
      | CreatePreforkGenesis : { network : Network.Type }
      | DaemonStorageToolbox
      | LogProc
      | ArchiveGeneric
      | Archive : { network : Network.Type }
      | RosettaGeneric
      | Rosetta : { network : Network.Type }
      | TestExecutive
      | TxTools
      | MinaBootstrap
      | FunctionalTestSuite
      | DelegationVerifier
      | Toolchain
      >

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = \(a : { network : Network.Type }) -> "Daemon"
            , DaemonGeneric = "DaemonGeneric"
            , DaemonProfiled =
                \(a : { profile : Profiles.Type }) -> "DaemonProfiled"
            , DaemonLegacyHardfork =
                \(a : { network : Network.Type }) -> "DaemonLegacyHardfork"
            , DaemonAutoHardfork =
                \(a : { network : Network.Type }) -> "DaemonAutoHardfork"
            , DaemonPrefork =
                \(a : { network : Network.Type }) -> "DaemonPrefork"
            , DaemonPostfork =
                \(a : { network : Network.Type }) -> "DaemonPostfork"
            , CreatePreforkGenesis =
                \(a : { network : Network.Type }) -> "CreatePreforkGenesis"
            , DaemonStorageToolbox = "DaemonStorageToolbox"
            , LogProc = "LogProc"
            , ArchiveGeneric = "ArchiveGeneric"
            , Archive = \(a : { network : Network.Type }) -> "Archive"
            , RosettaGeneric = "RosettaGeneric"
            , Rosetta = \(a : { network : Network.Type }) -> "Rosetta"
            , TestExecutive = "TestExecutive"
            , TxTools = "TxTools"
            , MinaBootstrap = "MinaBootstrap"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , DelegationVerifier = "DelegationVerifier"
            , Toolchain = "Toolchain"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = \(a : { network : Network.Type }) -> "daemon"
            , DaemonGeneric = "daemonGeneric"
            , DaemonProfiled =
                \(a : { profile : Profiles.Type }) -> "daemonProfiled"
            , DaemonLegacyHardfork =
                \(a : { network : Network.Type }) -> "daemonLegacyHardfork"
            , DaemonAutoHardfork =
                \(a : { network : Network.Type }) -> "daemonAutoHardfork"
            , DaemonPrefork =
                \(a : { network : Network.Type }) -> "daemonPrefork"
            , DaemonPostfork =
                \(a : { network : Network.Type }) -> "daemonPostfork"
            , CreatePreforkGenesis =
                \(a : { network : Network.Type }) -> "createPreforkGenesis"
            , DaemonStorageToolbox = "daemonStorageToolbox"
            , LogProc = "logProc"
            , ArchiveGeneric = "archiveGeneric"
            , Archive = \(a : { network : Network.Type }) -> "archive"
            , RosettaGeneric = "rosettaGeneric"
            , Rosetta = \(a : { network : Network.Type }) -> "rosetta"
            , TestExecutive = "testExecutive"
            , TxTools = "txTools"
            , MinaBootstrap = "minaBootstrap"
            , FunctionalTestSuite = "functionalTestSuite"
            , DelegationVerifier = "delegationVerifier"
            , Toolchain = "toolchain"
            }
            artifact

let isNetworked =
          \(artifact : Artifact)
      ->  merge
            { Daemon = \(a : { network : Network.Type }) -> True
            , DaemonGeneric = False
            , DaemonProfiled = \(a : { profile : Profiles.Type }) -> False
            , DaemonLegacyHardfork = \(a : { network : Network.Type }) -> True
            , DaemonAutoHardfork = \(a : { network : Network.Type }) -> True
            , DaemonPrefork = \(a : { network : Network.Type }) -> True
            , DaemonPostfork = \(a : { network : Network.Type }) -> True
            , CreatePreforkGenesis = \(a : { network : Network.Type }) -> True
            , DaemonStorageToolbox = False
            , LogProc = False
            , ArchiveGeneric = False
            , Archive = \(a : { network : Network.Type }) -> True
            , RosettaGeneric = False
            , Rosetta = \(a : { network : Network.Type }) -> True
            , TestExecutive = False
            , TxTools = False
            , MinaBootstrap = False
            , FunctionalTestSuite = False
            , DelegationVerifier = False
            , Toolchain = False
            }
            artifact

let network =
          \(artifact : Artifact)
      ->  merge
            { Daemon = \(a : { network : Network.Type }) -> Some a.network
            , DaemonGeneric = None Network.Type
            , DaemonProfiled =
                \(a : { profile : Profiles.Type }) -> None Network.Type
            , DaemonLegacyHardfork =
                \(a : { network : Network.Type }) -> Some a.network
            , DaemonAutoHardfork =
                \(a : { network : Network.Type }) -> Some a.network
            , DaemonPrefork =
                \(a : { network : Network.Type }) -> Some a.network
            , DaemonPostfork =
                \(a : { network : Network.Type }) -> Some a.network
            , CreatePreforkGenesis =
                \(a : { network : Network.Type }) -> Some a.network
            , DaemonStorageToolbox = None Network.Type
            , LogProc = None Network.Type
            , ArchiveGeneric = None Network.Type
            , Archive = \(a : { network : Network.Type }) -> Some a.network
            , RosettaGeneric = None Network.Type
            , Rosetta = \(a : { network : Network.Type }) -> Some a.network
            , TestExecutive = None Network.Type
            , TxTools = None Network.Type
            , MinaBootstrap = None Network.Type
            , FunctionalTestSuite = None Network.Type
            , DelegationVerifier = None Network.Type
            , Toolchain = None Network.Type
            }
            artifact

let resolvedNetwork =
          \(artifact : Artifact)
      ->  merge
            { Some = \(n : Network.Type) -> n, None = Network.Type.Devnet }
            (network artifact)

let profile =
          \(artifact : Artifact)
      ->  merge
            { Daemon =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , DaemonGeneric = Profiles.Type.Devnet
            , DaemonProfiled = \(a : { profile : Profiles.Type }) -> a.profile
            , DaemonLegacyHardfork =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , DaemonAutoHardfork =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , DaemonPrefork =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , DaemonPostfork =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , CreatePreforkGenesis =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , DaemonStorageToolbox = Profiles.Type.Devnet
            , LogProc = Profiles.Type.Devnet
            , ArchiveGeneric = Profiles.Type.Devnet
            , Archive =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , RosettaGeneric = Profiles.Type.Devnet
            , Rosetta =
                    \(a : { network : Network.Type })
                ->  Profiles.fromNetwork a.network
            , TestExecutive = Profiles.Type.Devnet
            , TxTools = Profiles.Type.Devnet
            , MinaBootstrap = Profiles.Type.Devnet
            , FunctionalTestSuite = Profiles.Type.Devnet
            , DelegationVerifier = Profiles.Type.Devnet
            , Toolchain = Profiles.Type.Devnet
            }
            artifact

let toDebian =
          \(artifact : Artifact)
      ->  merge
            { Daemon =
                \(a : { network : Network.Type }) -> Debian.Type.DaemonConfig
            , DaemonGeneric = Debian.Type.DaemonGeneric
            , DaemonProfiled =
                \(a : { profile : Profiles.Type }) -> Debian.Type.Profile
            , DaemonLegacyHardfork =
                    \(a : { network : Network.Type })
                ->  Debian.Type.DaemonHardforkConfig
            , DaemonAutoHardfork =
                \(a : { network : Network.Type }) -> Debian.Type.DaemonAutomode
            , DaemonPrefork =
                \(a : { network : Network.Type }) -> Debian.Type.DaemonPrefork
            , DaemonPostfork =
                \(a : { network : Network.Type }) -> Debian.Type.DaemonPostfork
            , CreatePreforkGenesis =
                    \(a : { network : Network.Type })
                ->  Debian.Type.PreforkGenesisLedger
            , DaemonStorageToolbox = Debian.Type.DaemonStorageToolbox
            , LogProc = Debian.Type.LogProc
            , ArchiveGeneric = Debian.Type.ArchiveGeneric
            , Archive = \(a : { network : Network.Type }) -> Debian.Type.Archive
            , RosettaGeneric = Debian.Type.RosettaGeneric
            , Rosetta = \(a : { network : Network.Type }) -> Debian.Type.Rosetta
            , TestExecutive = Debian.Type.TestExecutive
            , TxTools = Debian.Type.TxTools
            , MinaBootstrap = Debian.Type.MinaBootstrap
            , FunctionalTestSuite = Debian.Type.FunctionalTestSuite
            , DelegationVerifier = Debian.Type.DelegationVerifier
            , Toolchain = Debian.Type.DaemonGeneric
            }
            artifact

let toDebians =
          \(artifacts : List Artifact)
      ->  List/map Artifact Debian.Type toDebian artifacts

let toDebianToken =
          \(artifact : Artifact)
      ->  Debian.buildToken
            (toDebian artifact)
            (profile artifact)
            (resolvedNetwork artifact)

let profileTentTokens =
    -- The mina-<network>-generic tent, as a debian build token, for the
    -- artifacts that have one.
    --
    -- The tent is an apt convenience metapackage: it holds no files and depends
    -- on mina-generic and mina-<network>-profile, so that `apt-get install
    -- mina-devnet-generic` gives a working daemon with the profile baked in. It
    -- therefore belongs to the job that builds that profile, which is the job
    -- that holds the matching DaemonProfiled artifact, and to no other.
    --
    -- Lightnet and Dev have no tent: they ship directly as mina-<profile>.
          \(artifact : Artifact)
      ->  merge
            { Daemon = \(a : { network : Network.Type }) -> [] : List Text
            , DaemonGeneric = [] : List Text
            , DaemonProfiled =
                    \(a : { profile : Profiles.Type })
                ->  merge
                      { Devnet = [ "profile_devnet_generic" ]
                      , Mainnet = [ "profile_mainnet_generic" ]
                      , Lightnet = [] : List Text
                      , Dev = [] : List Text
                      }
                      a.profile
            , DaemonLegacyHardfork =
                \(a : { network : Network.Type }) -> [] : List Text
            , DaemonAutoHardfork =
                \(a : { network : Network.Type }) -> [] : List Text
            , DaemonPrefork =
                \(a : { network : Network.Type }) -> [] : List Text
            , DaemonPostfork =
                \(a : { network : Network.Type }) -> [] : List Text
            , CreatePreforkGenesis =
                \(a : { network : Network.Type }) -> [] : List Text
            , DaemonStorageToolbox = [] : List Text
            , LogProc = [] : List Text
            , ArchiveGeneric = [] : List Text
            , Archive = \(a : { network : Network.Type }) -> [] : List Text
            , RosettaGeneric = [] : List Text
            , Rosetta = \(a : { network : Network.Type }) -> [] : List Text
            , TestExecutive = [] : List Text
            , TxTools = [] : List Text
            , MinaBootstrap = [] : List Text
            , FunctionalTestSuite = [] : List Text
            , DelegationVerifier = [] : List Text
            , Toolchain = [] : List Text
            }
            artifact

let profileTents =
          \(artifacts : List Artifact)
      ->  List/concatMap Artifact Text profileTentTokens artifacts

let networkOrdinal = \(n : Network.Type) -> merge { Devnet = 0, Mainnet = 1 } n

let networks =
          \(artifacts : List Artifact)
      ->  let collected =
                Prelude.List.concatMap
                  Artifact
                  Network.Type
                  (     \(a : Artifact)
                    ->  merge
                          { Some = \(n : Network.Type) -> [ n ]
                          , None = [] : List Network.Type
                          }
                          (network a)
                  )
                  artifacts

          in  Prelude.List.fold
                Network.Type
                collected
                (List Network.Type)
                (     \(n : Network.Type)
                  ->  \(acc : List Network.Type)
                  ->        if Prelude.List.any
                                 Network.Type
                                 (     \(m : Network.Type)
                                   ->  Prelude.Natural.equal
                                         (networkOrdinal n)
                                         (networkOrdinal m)
                                 )
                                 acc

                      then  acc

                      else  [ n ] # acc
                )
                ([] : List Network.Type)

in  { Type = Artifact
    , capitalName = capitalName
    , lowerName = lowerName
    , isNetworked = isNetworked
    , network = network
    , resolvedNetwork = resolvedNetwork
    , profile = profile
    , toDebian = toDebian
    , toDebians = toDebians
    , toDebianToken = toDebianToken
    , networks = networks
    , profileTents = profileTents
    }
