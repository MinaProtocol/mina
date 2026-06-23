let Prelude = ../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let Profiles = ./Profiles.dhall

let Network = ./Network.dhall

let BuildFlags = ./BuildFlags.dhall

let Repo = ./DockerRepo.dhall

let Artifact
    : Type
    = < DaemonLegacyHardfork
      | DaemonAppsOnly
      | DaemonPrefork
      | DaemonAutoHardfork
      | DaemonAutomode
      | DaemonConfig
      | LogProc
      | Archive
      | TestExecutive
      | TxTools
      | MinaBootstrap
      | RosettaAppsOnly
      | RosettaConfig
      | FunctionalTestSuite
      | Toolchain
      | CreatePreforkGenesis
      | DelegationVerifier
      | DaemonStorageToolbox
      >

let All =
      [ Artifact.DaemonLegacyHardfork
      , Artifact.DaemonPrefork
      , Artifact.DaemonAutoHardfork
      , Artifact.DaemonAutomode
      , Artifact.DaemonAppsOnly
      , Artifact.DaemonConfig
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.TxTools
      , Artifact.MinaBootstrap
      , Artifact.TestExecutive
      , Artifact.RosettaAppsOnly
      , Artifact.RosettaConfig
      , Artifact.Toolchain
      , Artifact.CreatePreforkGenesis
      , Artifact.DelegationVerifier
      , Artifact.DaemonStorageToolbox
      ]

let Main =
      [ Artifact.DaemonConfig
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.RosettaConfig
      ]

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { DaemonPrefork = "DaemonPrefork"
            , DaemonLegacyHardfork = "DaemonLegacyHardfork"
            , DaemonAutoHardfork = "DaemonAutoHardfork"
            , DaemonAutomode = "DaemonAutomode"
            , DaemonAppsOnly = "DaemonAppsOnly"
            , DaemonConfig = "DaemonConfig"
            , LogProc = "LogProc"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , TxTools = "TxTools"
            , MinaBootstrap = "MinaBootstrap"
            , RosettaAppsOnly = "RosettaAppsOnly"
            , RosettaConfig = "RosettaConfig"
            , DelegationVerifier = "DelegationVerifier"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , Toolchain = "Toolchain"
            , CreatePreforkGenesis = "CreatePreforkGenesis"
            , DaemonStorageToolbox = "DaemonStorageToolbox"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { DaemonPrefork = "daemon_prefork"
            , DaemonLegacyHardfork = "daemon_hardfork"
            , DaemonAutoHardfork = "daemon_auto_hardfork"
            , DaemonAutomode = "daemon_automode"
            , DaemonAppsOnly = "daemon_apps_only"
            , DaemonConfig = "daemon_config"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , TxTools = "tx_tools"
            , MinaBootstrap = "mina_bootstrap"
            , RosettaAppsOnly = "rosetta_apps_only"
            , RosettaConfig = "rosetta_config"
            , FunctionalTestSuite = "functional_test_suite"
            , CreatePreforkGenesis = "create_prefork_genesis"
            , DaemonStorageToolbox = "daemon_storage_toolbox"
            , Toolchain = "toolchain"
            , DelegationVerifier = "delegation_verifier"
            }
            artifact

let dockerServiceName =
          \(artifact : Artifact)
      ->  merge
            { DaemonPrefork = ""
            , DaemonLegacyHardfork = "mina-daemon-legacy-hardfork"
            , DaemonAutoHardfork = "mina-daemon-auto-hardfork"
            , DaemonAutomode = ""
            , DaemonAppsOnly = "mina-daemon"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , LogProc = "mina-logproc"
            , TxTools = "mina-tx-tools"
            , MinaBootstrap = "mina-bootstrap"
            , RosettaAppsOnly = "mina-rosetta"
            , RosettaConfig = "mina-rosetta-configured"
            , FunctionalTestSuite = "mina-test-suite"
            , Toolchain = "mina-toolchain"
            , CreatePreforkGenesis = ""
            , DelegationVerifier = "mina-delegation-verifier"
            , DaemonStorageToolbox = "mina-daemon-storage-toolbox"
            , DaemonConfig = "mina-daemon-configured"
            }
            artifact

let dockerName =
          \(artifact : Artifact)
      ->  merge
            { DaemonConfig = "mina-daemon"
            , DaemonPrefork = dockerServiceName artifact
            , DaemonLegacyHardfork = dockerServiceName artifact
            , DaemonAutoHardfork = dockerServiceName artifact
            , DaemonAppsOnly = dockerServiceName artifact
            , DaemonAutomode = dockerServiceName artifact
            , Archive = dockerServiceName artifact
            , TestExecutive = dockerServiceName artifact
            , LogProc = dockerServiceName artifact
            , TxTools = dockerServiceName artifact
            , MinaBootstrap = dockerServiceName artifact
            , RosettaAppsOnly = dockerServiceName artifact
            , RosettaConfig = "mina-rosetta"
            , FunctionalTestSuite = dockerServiceName artifact
            , Toolchain = dockerServiceName artifact
            , CreatePreforkGenesis = dockerServiceName artifact
            , DelegationVerifier = dockerServiceName artifact
            , DaemonStorageToolbox = dockerServiceName artifact
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
            { DaemonPrefork = "daemon_${Network.lowerName network}_prefork"
            , DaemonLegacyHardfork =
                "daemon_${Network.lowerName network}_hardfork_config"
            , DaemonAutoHardfork =
                "daemon_${Network.lowerName network}_postfork"
            , DaemonAutomode = "daemon_${Network.lowerName network}_automode"
            , DaemonAppsOnly = "daemon_${Network.lowerName network}_generic"
            , LogProc = "logproc"
            , Archive = "archive_${Network.lowerName network}"
            , TestExecutive = "test_executive"
            , TxTools = "tx_tools"
            , RosettaAppsOnly = "rosetta_${Network.lowerName network}"
            , MinaBootstrap = "mina_bootstrap"
            , RosettaConfig = ""
            , FunctionalTestSuite = "functional_test_suite"
            , Toolchain = ""
            , DelegationVerifier = "delegation_verifier"
            , CreatePreforkGenesis =
                "prefork_${Network.lowerName network}_genesis_ledger"
            , DaemonConfig = "daemon_${Network.lowerName network}_config"
            , DaemonStorageToolbox = "daemon_storage_toolbox"
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
                          { DaemonPrefork = [ toDebianName a network ]
                          , DaemonLegacyHardfork = [ toDebianName a network ]
                          , DaemonAutoHardfork = [ toDebianName a network ]
                          , DaemonAutomode = [ toDebianName a network ]
                          , DaemonConfig = [ toDebianName a network ]
                          , DaemonAppsOnly = [ toDebianName a network ]
                          , Archive = [ toDebianName a network ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , TxTools = [ "tx_tools" ]
                          , MinaBootstrap = [ "mina_bootstrap" ]
                          , RosettaAppsOnly = [ toDebianName a network ]
                          , RosettaConfig = [ toDebianName a network ]
                          , FunctionalTestSuite = [ "functional_test_suite" ]
                          , CreatePreforkGenesis = [ toDebianName a network ]
                          , DelegationVerifier = [ "delegation_verify" ]
                          , DaemonStorageToolbox = [ "daemon_storage_toolbox" ]
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
          { artifact = Artifact.DaemonConfig
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
                { DaemonPrefork = ""
                , DaemonAutomode = ""
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
                , TxTools = "${spec.version}"
                , MinaBootstrap = "${spec.version}"
                , RosettaConfig =
                    "${spec.version}${network_part}${extraordinary_profile_part}${extra_build_flags_part}"
                , RosettaAppsOnly =
                    "${spec.version}${network_part}-generic${extraordinary_profile_part}${extra_build_flags_part}"
                , FunctionalTestSuite =
                    "${spec.version}${extra_build_flags_part}"
                , Toolchain = "${spec.version}"
                , DelegationVerifier = "${spec.version}"
                , CreatePreforkGenesis = "${spec.version}"
                , DaemonConfig =
                    "${spec.version}${network_part}${extraordinary_profile_part}${extra_build_flags_part}"
                , DaemonStorageToolbox = "${spec.version}"
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
               { artifact = Artifact.DaemonConfig
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
               { artifact = Artifact.DaemonConfig
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
               { artifact = Artifact.DaemonConfig
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
               { artifact = Artifact.RosettaConfig
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
               { artifact = Artifact.RosettaConfig
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
               { artifact = Artifact.DaemonConfig
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
    , dockerServiceName = dockerServiceName
    , dockerName = dockerName
    , dockerNames = dockerNames
    , dockerTag = dockerTag
    , fullDockerTag = fullDockerTag
    , All = All
    , Main = Main
    }
