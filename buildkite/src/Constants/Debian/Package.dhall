let Prelude = ../../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let Network = ../Network.dhall

let Profile = ../Profiles.dhall

let Package
    : Type
    = < Profile
      | DaemonGeneric
      | DaemonConfig
      | DaemonHardforkConfig
      | DaemonAutomode
      | DaemonPostfork
      | DaemonPrefork
      | DaemonStorageToolbox
      | PreforkGenesisLedger
      | Archive
      | ArchiveGeneric
      | RosettaGeneric
      | Rosetta
      | TestExecutive
      | TxTools
      | LogProc
      | FunctionalTestSuite
      | DelegationVerifier
      >

let All =
      [ Package.Profile
      , Package.DaemonGeneric
      , Package.DaemonConfig
      , Package.DaemonHardforkConfig
      , Package.DaemonAutomode
      , Package.DaemonPostfork
      , Package.DaemonPrefork
      , Package.DaemonStorageToolbox
      , Package.PreforkGenesisLedger
      , Package.Archive
      , Package.ArchiveGeneric
      , Package.RosettaGeneric
      , Package.Rosetta
      , Package.TestExecutive
      , Package.TxTools
      , Package.LogProc
      , Package.FunctionalTestSuite
      , Package.DelegationVerifier
      ]

let MainPackages =
      [ Package.DaemonGeneric
      , Package.DaemonConfig
      , Package.Archive
      , Package.ArchiveGeneric
      , Package.LogProc
      , Package.RosettaGeneric
      , Package.Rosetta
      ]

let AuxiliaryPackages =
      [ Package.Profile
      , Package.DaemonHardforkConfig
      , Package.DaemonAutomode
      , Package.DaemonPostfork
      , Package.DaemonPrefork
      , Package.DaemonStorageToolbox
      , Package.PreforkGenesisLedger
      , Package.TestExecutive
      , Package.TxTools
      , Package.FunctionalTestSuite
      , Package.DelegationVerifier
      ]

let index =
          \(package : Package)
      ->  merge
            { Profile = 0
            , DaemonGeneric = 1
            , DaemonConfig = 2
            , DaemonHardforkConfig = 3
            , DaemonAutomode = 4
            , DaemonPostfork = 5
            , DaemonPrefork = 6
            , DaemonStorageToolbox = 7
            , PreforkGenesisLedger = 8
            , Archive = 9
            , ArchiveGeneric = 10
            , RosettaGeneric = 11
            , Rosetta = 12
            , TestExecutive = 13
            , TxTools = 14
            , LogProc = 15
            , FunctionalTestSuite = 16
            , DelegationVerifier = 17
            }
            package

let isNetworked =
          \(package : Package)
      ->  merge
            { Profile = False
            , DaemonGeneric = False
            , DaemonConfig = True
            , DaemonHardforkConfig = True
            , DaemonAutomode = True
            , DaemonPostfork = True
            , DaemonPrefork = True
            , DaemonStorageToolbox = False
            , PreforkGenesisLedger = True
            , Archive = True
            , ArchiveGeneric = False
            , RosettaGeneric = False
            , Rosetta = True
            , TestExecutive = False
            , TxTools = False
            , LogProc = False
            , FunctionalTestSuite = False
            , DelegationVerifier = False
            }
            package

let capitalName =
          \(package : Package)
      ->  merge
            { Profile = "Profile"
            , DaemonGeneric = "DaemonGeneric"
            , DaemonConfig = "DaemonConfig"
            , DaemonHardforkConfig = "DaemonHardforkConfig"
            , DaemonAutomode = "DaemonAutomode"
            , DaemonPostfork = "DaemonPostfork"
            , DaemonPrefork = "DaemonPrefork"
            , DaemonStorageToolbox = "DaemonStorageToolbox"
            , PreforkGenesisLedger = "PreforkGenesisLedger"
            , Archive = "Archive"
            , ArchiveGeneric = "ArchiveGeneric"
            , RosettaGeneric = "RosettaGeneric"
            , Rosetta = "Rosetta"
            , TestExecutive = "TestExecutive"
            , TxTools = "TxTools"
            , LogProc = "LogProc"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , DelegationVerifier = "DelegationVerifier"
            }
            package

let lowerName =
          \(package : Package)
      ->  merge
            { Profile = "profile"
            , DaemonGeneric = "daemon_generic"
            , DaemonConfig = "daemon_config"
            , DaemonHardforkConfig = "daemon_hardfork_config"
            , DaemonAutomode = "daemon_automode"
            , DaemonPostfork = "daemon_postfork"
            , DaemonPrefork = "daemon_prefork"
            , DaemonStorageToolbox = "daemon_storage_toolbox"
            , PreforkGenesisLedger = "prefork_genesis_ledger"
            , Archive = "archive"
            , ArchiveGeneric = "archive_generic"
            , RosettaGeneric = "rosetta_generic"
            , Rosetta = "rosetta"
            , TestExecutive = "test_executive"
            , TxTools = "tx_tools"
            , LogProc = "logproc"
            , FunctionalTestSuite = "functional_test_suite"
            , DelegationVerifier = "delegation_verify"
            }
            package

let buildToken =
          \(package : Package)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  merge
            { Profile = "profile_${Profile.lowerName profile}"
            , DaemonGeneric = "daemon_generic"
            , DaemonConfig = "daemon_${Network.lowerName network}_config"
            , DaemonHardforkConfig =
                "daemon_${Network.lowerName network}_hardfork_config"
            , DaemonAutomode = "daemon_${Network.lowerName network}_automode"
            , DaemonPostfork = "daemon_${Network.lowerName network}_postfork"
            , DaemonPrefork = "daemon_${Network.lowerName network}_prefork"
            , DaemonStorageToolbox = "daemon_storage_toolbox"
            , PreforkGenesisLedger =
                "prefork_${Network.lowerName network}_genesis_ledger"
            , Archive = "archive_${Network.lowerName network}"
            , ArchiveGeneric = "archive_generic"
            , RosettaGeneric = "rosetta_generic"
            , Rosetta = "rosetta_${Network.lowerName network}"
            , TestExecutive = "test_executive"
            , TxTools = "tx_tools"
            , LogProc = "logproc"
            , FunctionalTestSuite = "functional_test_suite"
            , DelegationVerifier = "delegation_verify"
            }
            package

let buildTokens =
          \(packages : List Package)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  Text/concatSep
            " "
            ( Prelude.List.map
                Package
                Text
                (\(p : Package) -> buildToken p profile network)
                packages
            )

let aptName =
          \(package : Package)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  merge
            { Profile = Profile.profileName profile
            , DaemonGeneric = "mina-generic"
            , DaemonConfig = "mina-${Network.lowerName network}-config"
            , DaemonHardforkConfig = "mina-${Network.lowerName network}-config"
            , DaemonAutomode = "mina-${Network.lowerName network}-automode"
            , DaemonPostfork = "mina-${Network.lowerName network}-postfork-mesa"
            , DaemonPrefork = "mina-${Network.lowerName network}-prefork-mesa"
            , DaemonStorageToolbox = "mina-daemon-storage-toolbox"
            , PreforkGenesisLedger =
                "mina-create-${Network.lowerName
                                 network}-prefork-genesis-ledger"
            , Archive = "mina-archive-${Network.lowerName network}"
            , ArchiveGeneric = "mina-archive-generic"
            , RosettaGeneric = "mina-rosetta-generic"
            , Rosetta = "mina-rosetta-${Network.lowerName network}"
            , TestExecutive = "mina-test-executive"
            , TxTools = "mina-tx-tools"
            , LogProc = "mina-logproc"
            , FunctionalTestSuite = "mina-test-suite"
            , DelegationVerifier = "mina-delegation-verifier"
            }
            package

let aptNames =
          \(packages : List Package)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  Prelude.List.map
            Package
            Text
            (\(p : Package) -> aptName p profile network)
            packages

let test_profile_token =
        assert
      :     "profile_lightnet"
        ===  buildToken
               Package.Profile
               Profile.Type.Lightnet
               Network.Type.Devnet

let test_profile_apt =
        assert
      :     "mina-lightnet"
        ===  aptName Package.Profile Profile.Type.Lightnet Network.Type.Devnet

let test_profile_apt =
        assert
      :     "mina-devnet-profile"
        ===  aptName Package.Profile Profile.Type.Devnet Network.Type.Devnet

let test_daemon_config_token =
        assert
      :     "daemon_devnet_config"
        ===  buildToken
               Package.DaemonConfig
               Profile.Type.Devnet
               Network.Type.Devnet

let test_daemon_config_apt =
        assert
      :     "mina-devnet-config"
        ===  aptName
               Package.DaemonConfig
               Profile.Type.Devnet
               Network.Type.Devnet

let test_archive_apt =
        assert
      :     "mina-archive-mainnet"
        ===  aptName Package.Archive Profile.Type.Mainnet Network.Type.Mainnet

let test_functional_suite_apt =
        assert
      :     "mina-test-suite"
        ===  aptName
               Package.FunctionalTestSuite
               Profile.Type.Devnet
               Network.Type.Devnet

in  { Type = Package
    , All = All
    , MainPackages = MainPackages
    , AuxiliaryPackages = AuxiliaryPackages
    , index = index
    , isNetworked = isNetworked
    , capitalName = capitalName
    , lowerName = lowerName
    , buildToken = buildToken
    , buildTokens = buildTokens
    , aptName = aptName
    , aptNames = aptNames
    }
