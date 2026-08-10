let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

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

let ordinal =
          \(artifact : Artifact)
      ->  merge
            { Daemon = \(a : { network : Network.Type }) -> 0
            , DaemonGeneric = 1
            , DaemonProfiled = \(a : { profile : Profiles.Type }) -> 2
            , DaemonLegacyHardfork = \(a : { network : Network.Type }) -> 3
            , DaemonAutoHardfork = \(a : { network : Network.Type }) -> 4
            , DaemonPrefork = \(a : { network : Network.Type }) -> 5
            , DaemonPostfork = \(a : { network : Network.Type }) -> 6
            , CreatePreforkGenesis = \(a : { network : Network.Type }) -> 7
            , DaemonStorageToolbox = 8
            , LogProc = 9
            , ArchiveGeneric = 10
            , Archive = \(a : { network : Network.Type }) -> 11
            , RosettaGeneric = 12
            , Rosetta = \(a : { network : Network.Type }) -> 13
            , TestExecutive = 14
            , TxTools = 15
            , FunctionalTestSuite = 16
            , DelegationVerifier = 17
            , Toolchain = 18
            }
            artifact

let requires =
          \(artifact : Artifact)
      ->  let daemonBase =
                [ Artifact.DaemonGeneric
                , Artifact.LogProc
                , Artifact.DaemonStorageToolbox
                ]

          let none = [] : List Artifact

          in  merge
                { Daemon = \(a : { network : Network.Type }) -> daemonBase
                , DaemonGeneric =
                  [ Artifact.LogProc, Artifact.DaemonStorageToolbox ]
                , DaemonProfiled =
                    \(a : { profile : Profiles.Type }) -> daemonBase
                , DaemonLegacyHardfork =
                        \(a : { network : Network.Type })
                    ->  [ Artifact.Daemon { network = a.network } ]
                , DaemonAutoHardfork =
                        \(a : { network : Network.Type })
                    ->  [ Artifact.Daemon { network = a.network } ]
                , DaemonPrefork = \(a : { network : Network.Type }) -> none
                , DaemonPostfork = \(a : { network : Network.Type }) -> none
                , CreatePreforkGenesis =
                    \(a : { network : Network.Type }) -> none
                , DaemonStorageToolbox = none
                , LogProc = none
                , ArchiveGeneric = none
                , Archive = \(a : { network : Network.Type }) -> none
                , RosettaGeneric = [ Artifact.LogProc ]
                , Rosetta =
                        \(a : { network : Network.Type })
                    ->  [ Artifact.RosettaGeneric
                        , Artifact.Daemon { network = a.network }
                        , Artifact.LogProc
                        ]
                , TestExecutive = none
                , TxTools = none
                , FunctionalTestSuite = none
                , DelegationVerifier = none
                , Toolchain = none
                }
                artifact

let hasOrdinal =
          \(artifacts : List Artifact)
      ->  \(artifact : Artifact)
      ->  Prelude.List.any
            Artifact
            (     \(other : Artifact)
              ->  Prelude.Natural.equal (ordinal other) (ordinal artifact)
            )
            artifacts

let dedupe =
          \(artifacts : List Artifact)
      ->  Prelude.List.reverse
            Artifact
            ( Prelude.List.fold
                Artifact
                artifacts
                (List Artifact)
                (     \(artifact : Artifact)
                  ->  \(kept : List Artifact)
                  ->        if hasOrdinal kept artifact

                      then  kept

                      else  [ artifact ] # kept
                )
                ([] : List Artifact)
            )

let addRequired =
          \(artifacts : List Artifact)
      ->  dedupe
            (   artifacts
              # Prelude.List.concatMap Artifact Artifact requires artifacts
            )

let close =
          \(artifacts : List Artifact)
      ->  addRequired (addRequired (addRequired (addRequired artifacts)))

in  { Type = Artifact
    , capitalName = capitalName
    , lowerName = lowerName
    , ordinal = ordinal
    , requires = requires
    , dedupe = dedupe
    , close = close
    , isNetworked = isNetworked
    , network = network
    , resolvedNetwork = resolvedNetwork
    , profile = profile
    , toDebian = toDebian
    , toDebians = toDebians
    , toDebianToken = toDebianToken
    , networks = networks
    }
