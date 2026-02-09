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
      | DaemonAutoHardfork
      | DaemonConfig
      | LogProc
      | Archive
      | TestExecutive
      | BatchTxn
      | Rosetta
      | ZkappTestTransaction
      | FunctionalTestSuite
      | Toolchain
      | PreforkGenesisLedger
      | DelegationVerifier
      | PreforkDaemon
      >

let AllButTests =
      [ Artifact.Daemon
      , Artifact.DaemonLegacyHardfork
      , Artifact.DaemonAutoHardfork
      , Artifact.DaemonConfig
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.BatchTxn
      , Artifact.TestExecutive
      , Artifact.Rosetta
      , Artifact.ZkappTestTransaction
      , Artifact.Toolchain
      , Artifact.PreforkDaemon
      , Artifact.PreforkGenesisLedger
      , Artifact.DelegationVerifier
      ]

let Main =
      [ Artifact.Daemon
      , Artifact.PreforkDaemon
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
            , DaemonLegacyHardfork = "DaemonLegacyHardfork"
            , DaemonAutoHardfork = "DaemonAutoHardfork"
            , DaemonConfig = "DaemonConfig"
            , PreforkDaemon = "PreforkDaemon"
            , LogProc = "LogProc"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , BatchTxn = "BatchTxn"
            , Rosetta = "Rosetta"
            , ZkappTestTransaction = "ZkappTestTransaction"
            , DelegationVerifier = "DelegationVerifier"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , Toolchain = "Toolchain"
            , PreforkGenesisLedger = "PreforkGenesisLedger"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "daemon"
            , DaemonLegacyHardfork = "daemon_legacy_hardfork"
            , DaemonAutoHardfork = "daemon_auto_hardfork"
            , DaemonConfig = "daemon_config"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , PreforkGenesisLedger = "prefork_genesis_ledger"
            , PreforkDaemon = "prefork_daemon"
            , Toolchain = "toolchain"
            , DelegationVerifier = "delegation_verifier"
            }
            artifact

let dockerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "mina-daemon"
            , DaemonLegacyHardfork = "mina-daemon-legacy-hardfork"
            , DaemonAutoHardfork = "mina-daemon-auto-hardfork"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , LogProc = "mina-logproc"
            , BatchTxn = "mina-batch-txn"
            , Rosetta = "mina-rosetta"
            , ZkappTestTransaction = "mina-zkapp-test-transaction"
            , FunctionalTestSuite = "mina-test-suite"
            , Toolchain = "mina-toolchain"
            , PreforkGenesisLedger = ""
            , PreforkDaemon = ""
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
            , DaemonLegacyHardfork =
                "daemon_${Network.lowerName network}_hardfork_config"
            , DaemonAutoHardfork =
                "daemon_${Network.lowerName network}_pre_hardfork"
            , LogProc = "logproc"
            , Archive = "archive_${Network.lowerName network}"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta_${Network.lowerName network}"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , Toolchain = ""
            , DelegationVerifier = "delegation_verifier"
            , PreforkGenesisLedger = "prefork_genesis_ledger"
            , PreforkDaemon = "daemon_${Network.lowerName network}_prefork"
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
                          , DaemonAutoHardfork = [ toDebianName a network ]
                          , DaemonLegacyHardfork =
                            [ toDebianName a network
                            , "daemon_${Network.lowerName
                                          network}_hardfork_config"
                            ]
                          , DaemonConfig = [ toDebianName a network ]
                          , Archive = [ toDebianName a network ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , BatchTxn = [ "batch_txn" ]
                          , Rosetta = [ "rosetta_${Network.lowerName network}" ]
                          , ZkappTestTransaction = [ "zkapp_test_transaction" ]
                          , FunctionalTestSuite = [ "functional_test_suite" ]
                          , PreforkGenesisLedger = [ "prefork_genesis_ledger" ]
                          , PreforkDaemon =
                            [ "daemon_${Network.lowerName network}_pre_hardfork"
                            ]
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
          , network = Network.Type.TestnetGeneric
          , remove_profile_from_name = False
          }
      }

let dockerTag =
          \(spec : Tag.Type)
      ->  let profile_part =
                      if spec.remove_profile_from_name

                then  ""

                else  "${Profiles.toLabelSegment spec.profile}"

          let build_flags_part =
                merge
                  { None = ""
                  , Instrumented =
                      "${BuildFlags.toLabelSegment spec.buildFlags}"
                  }
                  spec.buildFlags

          in  merge
                { Daemon =
                    "${spec.version}-${Network.debianSuffix
                                         spec.network}${profile_part}${build_flags_part}"
                , DaemonLegacyHardfork =
                    "${spec.version}-${Network.debianSuffix
                                         spec.network}${profile_part}"
                , DaemonAutoHardfork =
                    "${spec.version}-${Network.debianSuffix
                                         spec.network}${profile_part}"
                , Archive = "${spec.version}${build_flags_part}"
                , LogProc = "${spec.version}"
                , TestExecutive = "${spec.version}"
                , BatchTxn = "${spec.version}"
                , Rosetta =
                    "${spec.version}-${Network.debianSuffix spec.network}"
                , ZkappTestTransaction = "${spec.version}"
                , FunctionalTestSuite = "${spec.version}${build_flags_part}"
                , Toolchain = "${spec.version}"
                , DelegationVerifier = "${spec.version}"
                , PreforkDaemon = "${spec.version}"
                , PreforkGenesisLedger = "${spec.version}"
                , DaemonConfig = "${spec.version}"
                }
                spec.artifact

let fullDockerTag =
          \(spec : Tag.Type)
      ->  "${Repo.show Repo.Type.InternalEurope}/${dockerName
                                                     spec.artifact}:${dockerTag
                                                                        spec}"

in  { Type = Artifact
    , Tag = Tag
    , capitalName = capitalName
    , lowerName = lowerName
    , toDebianNames = toDebianNames
    , dockerName = dockerName
    , dockerNames = dockerNames
    , dockerTag = dockerTag
    , fullDockerTag = fullDockerTag
    , All = All
    , AllButTests = AllButTests
    , Main = Main
    }
