let Prelude = ../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let Profiles = ./Profiles.dhall

let Network = ./Network.dhall

let BuildFlags = ./BuildFlags.dhall

let Repo = ./DockerRepo.dhall

let Artifact
    : Type
    = < Daemon
      | DaemonLegacyHardfork
      | DaemonAppsOnly
      | DaemonPrefork
      | DaemonAutoHardfork
      | DaemonConfig
      | LogProc
      | Archive
      | TestExecutive
      | BatchTxn
      | Rosetta
      | RosettaAppsOnly
      | ZkappTestTransaction
      | FunctionalTestSuite
      | Toolchain
      | CreatePreforkGenesis
      | DelegationVerifier
      >

let AllButTests =
      [ Artifact.Daemon
      , Artifact.DaemonLegacyHardfork
      , Artifact.DaemonPrefork
      , Artifact.DaemonAutoHardfork
      , Artifact.DaemonAppsOnly
      , Artifact.DaemonConfig
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.BatchTxn
      , Artifact.TestExecutive
      , Artifact.Rosetta
      , Artifact.ZkappTestTransaction
      , Artifact.RosettaAppsOnly
      , Artifact.Toolchain
      , Artifact.CreatePreforkGenesis
      , Artifact.DelegationVerifier
      ]

let Main =
      [ Artifact.Daemon
      , Artifact.DaemonConfig
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.Rosetta
      ]

let All = AllButTests # [ Artifact.FunctionalTestSuite ]

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "Daemon"
            , DaemonPrefork = "DaemonPrefork"
            , DaemonLegacyHardfork = "DaemonLegacyHardfork"
            , DaemonAutoHardfork = "DaemonAutoHardfork"
            , DaemonAppsOnly = "DaemonAppsOnly"
            , DaemonConfig = "DaemonConfig"
            , LogProc = "LogProc"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , BatchTxn = "BatchTxn"
            , Rosetta = "Rosetta"
            , RosettaAppsOnly = "RosettaAppsOnly"
            , ZkappTestTransaction = "ZkappTestTransaction"
            , DelegationVerifier = "DelegationVerifier"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , Toolchain = "Toolchain"
            , CreatePreforkGenesis = "CreatePreforkGenesis"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "daemon"
            , DaemonPrefork = "daemon_prefork"
            , DaemonLegacyHardfork = "daemon_hardfork"
            , DaemonAutoHardfork = "daemon_auto_hardfork"
            , DaemonAppsOnly = "daemon_apps_only"
            , DaemonConfig = "daemon_config"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta"
            , RosettaAppsOnly = "rosetta_apps_only"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , CreatePreforkGenesis = "create_prefork_genesis"
            , Toolchain = "toolchain"
            , DelegationVerifier = "delegation_verifier"
            }
            artifact

let dockerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "mina-daemon"
            , DaemonPrefork = ""
            , DaemonLegacyHardfork = "mina-daemon-pre-hardfork"
            , DaemonAutoHardfork = "mina-daemon-auto-hardfork"
            , DaemonAppsOnly = "mina-daemon"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , LogProc = "mina-logproc"
            , BatchTxn = "mina-batch-txn"
            , Rosetta = "mina-rosetta"
            , RosettaAppsOnly = "mina-rosetta"
            , ZkappTestTransaction = "mina-zkapp-test-transaction"
            , FunctionalTestSuite = "mina-test-suite"
            , Toolchain = "mina-toolchain"
            , CreatePreforkGenesis = ""
            , DelegationVerifier = "mina-delegation-verifier"
            , DaemonConfig = ""
            }
            artifact

let dockerNames =
          \(artifacts : List Artifact)
      ->  Prelude.List.map
            Artifact
            Text
            (\(a : Artifact) -> dockerName a)
            artifacts

let toDebianName =
          \(artifact : Artifact)
      ->  \(network : Network.Type)
      ->  merge
            { Daemon = "daemon_${Network.lowerName network}"
            , DaemonPrefork = "daemon_${Network.lowerName network}_prefork"
            , DaemonLegacyHardfork =
                "daemon_${Network.lowerName network}_hardfork_config"
            , DaemonAutoHardfork = ""
            , DaemonAppsOnly = "daemon_${Network.lowerName network}_generic"
            , LogProc = "logproc"
            , Archive = "archive_${Network.lowerName network}"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta_${Network.lowerName network}"
            , RosettaAppsOnly = ""
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , Toolchain = ""
            , DelegationVerifier = "delegation_verifier"
            , CreatePreforkGenesis =
                "prefork_${Network.lowerName network}_genesis_ledger"
            , DaemonConfig = "daemon_${Network.lowerName network}_config"
            }
            artifact

let toDebianNames =
          \(artifacts : List Artifact)
      ->  \(network : Network.Type)
      ->  let list_of_list_of_debians =
                Prelude.List.map
                  Artifact
                  (List Text)
                  (     \(a : Artifact)
                    ->  merge
                          { Daemon = [ toDebianName a network ]
                          , DaemonPrefork = [ toDebianName a network ]
                          , DaemonLegacyHardfork = [ toDebianName a network ]
                          , DaemonAutoHardfork = [ toDebianName a network ]
                          , DaemonConfig = [ toDebianName a network ]
                          , DaemonAppsOnly = [ toDebianName a network ]
                          , Archive = [ toDebianName a network ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , BatchTxn = [ "batch_txn" ]
                          , Rosetta = [ toDebianName a network ]
                          , RosettaAppsOnly = [ toDebianName a network ]
                          , ZkappTestTransaction = [ "zkapp_test_transaction" ]
                          , FunctionalTestSuite = [ "functional_test_suite" ]
                          , CreatePreforkGenesis = [ toDebianName a network ]
                          , DelegationVerifier = [ "delegation_verify" ]
                          , Toolchain = [] : List Text
                          }
                          a
                  )
                  artifacts

          let items =
                Prelude.List.fold
                  (List Text)
                  list_of_list_of_debians
                  (List Text)
                  (\(x : List Text) -> \(y : List Text) -> x # y)
                  ([] : List Text)

          in  Text/concatSep " " items

let Tag =
      { Type =
          { artifact : Artifact
          , version : Text
          , profile : Profiles.Type
          , network : Network.Type
          , buildFlags : BuildFlags.Type
          , remove_profile_from_name : Bool
          }
      , default =
          { artifact = Artifact.Daemon
          , version = "\\\${MINA_DOCKER_TAG}"
          , profile = Profiles.Type.Devnet
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Devnet
          , remove_profile_from_name = False
          }
      }

let dockerTag =
          \(spec : Tag.Type)
      ->  let network_part =
                merge
                  { Devnet = "${Network.toLabelSegment spec.network}"
                  , Mainnet = "${Network.toLabelSegment spec.network}"
                  , Lightnet = ""
                  , Dev = ""
                  }
                  spec.profile

          let extraordinary_profile_part =
                      if spec.remove_profile_from_name

                then  ""

                else  Profiles.toExtraLabelSegment spec.profile

          let extra_build_flags_part = BuildFlags.toLabelSegment spec.buildFlags

          in  merge
                { Daemon =
                    "${spec.version}${network_part}${extraordinary_profile_part}${extra_build_flags_part}"
                , DaemonPrefork = ""
                , DaemonLegacyHardfork =
                    "${spec.version}${network_part}${extraordinary_profile_part}"
                , DaemonAutoHardfork =
                    "${spec.version}${network_part}${extraordinary_profile_part}"
                , Archive =
                    "${spec.version}${network_part}${extraordinary_profile_part}${extra_build_flags_part}"
                , DaemonAppsOnly =
                    "${spec.version}${network_part}-generic${extraordinary_profile_part}${extra_build_flags_part}"
                , LogProc = "${spec.version}"
                , TestExecutive = "${spec.version}"
                , BatchTxn = "${spec.version}"
                , Rosetta =
                    "${spec.version}${network_part}${extraordinary_profile_part}${extra_build_flags_part}"
                , RosettaAppsOnly =
                    "${spec.version}${network_part}-generic${extraordinary_profile_part}${extra_build_flags_part}"
                , ZkappTestTransaction = "${spec.version}"
                , FunctionalTestSuite =
                    "${spec.version}${extra_build_flags_part}"
                , Toolchain = "${spec.version}"
                , DelegationVerifier = "${spec.version}"
                , CreatePreforkGenesis = "${spec.version}"
                , DaemonConfig = "${spec.version}"
                }
                spec.artifact

let fullDockerTag =
          \(spec : Tag.Type)
      ->  "${Repo.show Repo.Type.InternalEurope}/${dockerName
                                                     spec.artifact}:${dockerTag
                                                                        spec}"

let test_daemon_testnet_devnet =
        assert
      :     "1.0.0-devnet"
        ===  dockerTag
               { artifact = Artifact.Daemon
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_daemon_mainnet_mainnet =
        assert
      :     "1.0.0-mainnet"
        ===  dockerTag
               { artifact = Artifact.Daemon
               , version = "1.0.0"
               , profile = Profiles.Type.Mainnet
               , network = Network.Type.Mainnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_daemon_instrumented =
        assert
      :     "1.0.0-devnet-instrumented"
        ===  dockerTag
               { artifact = Artifact.Daemon
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.Instrumented
               , remove_profile_from_name = False
               }

let test_archive_testnet =
        assert
      :     "1.0.0-devnet"
        ===  dockerTag
               { artifact = Artifact.Archive
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_archive_instrumented =
        assert
      :     "1.0.0-devnet-instrumented"
        ===  dockerTag
               { artifact = Artifact.Archive
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.Instrumented
               , remove_profile_from_name = True
               }

let test_rosetta_testnet =
        assert
      :     "1.0.0-devnet"
        ===  dockerTag
               { artifact = Artifact.Rosetta
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_rosetta_mainnet =
        assert
      :     "1.0.0-mainnet"
        ===  dockerTag
               { artifact = Artifact.Rosetta
               , version = "1.0.0"
               , profile = Profiles.Type.Mainnet
               , network = Network.Type.Mainnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_daemon_legacy_hardfork_testnet =
        assert
      :     "1.0.0-devnet"
        ===  dockerTag
               { artifact = Artifact.DaemonLegacyHardfork
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_daemon_auto_hardfork_mainnet =
        assert
      :     "1.0.0-mainnet"
        ===  dockerTag
               { artifact = Artifact.DaemonAutoHardfork
               , version = "1.0.0"
               , profile = Profiles.Type.Mainnet
               , network = Network.Type.Mainnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_daemon_auto_hardfork_testnet =
        assert
      :     "1.0.0-devnet"
        ===  dockerTag
               { artifact = Artifact.DaemonAutoHardfork
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_daemon_generic =
        assert
      :     "1.0.0-devnet-generic"
        ===  dockerTag
               { artifact = Artifact.DaemonAppsOnly
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.None
               , remove_profile_from_name = False
               }

let test_lightnet_instrumented =
        assert
      :     "1.0.0-lightnet-instrumented"
        ===  dockerTag
               { artifact = Artifact.Daemon
               , version = "1.0.0"
               , profile = Profiles.Type.Lightnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.Instrumented
               , remove_profile_from_name = False
               }

let test_deamon_appsonly_instrumented =
        assert
      :     "1.0.0-devnet-generic-instrumented"
        ===  dockerTag
               { artifact = Artifact.DaemonAppsOnly
               , version = "1.0.0"
               , profile = Profiles.Type.Devnet
               , network = Network.Type.Devnet
               , buildFlags = BuildFlags.Type.Instrumented
               , remove_profile_from_name = True
               }

let test_deamon_appsonly_instrumented =
        assert
      :     "1.0.0-mainnet-generic-instrumented"
        ===  dockerTag
               { artifact = Artifact.RosettaAppsOnly
               , version = "1.0.0"
               , profile = Profiles.Type.Mainnet
               , network = Network.Type.Mainnet
               , buildFlags = BuildFlags.Type.Instrumented
               , remove_profile_from_name = True
               }

in  { Type = Artifact
    , Tag = Tag
    , capitalName = capitalName
    , lowerName = lowerName
    , toDebianName = toDebianName
    , toDebianNames = toDebianNames
    , dockerName = dockerName
    , dockerNames = dockerNames
    , dockerTag = dockerTag
    , fullDockerTag = fullDockerTag
    , All = All
    , AllButTests = AllButTests
    , Main = Main
    }
