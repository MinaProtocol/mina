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
      | LogProc
      | Archive
      | TestExecutive
      | BatchTxn
      | Rosetta
      | ZkappTestTransaction
      | FunctionalTestSuite
      | Toolchain
      | CreateLegacyGenesis
      >

let AllButTests =
      [ Artifact.Daemon
      , Artifact.DaemonLegacyHardfork
      , Artifact.DaemonAutoHardfork
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.BatchTxn
      , Artifact.TestExecutive
      , Artifact.Rosetta
      , Artifact.ZkappTestTransaction
      , Artifact.Toolchain
      , Artifact.CreateLegacyGenesis
      ]

let Main =
      [ Artifact.Daemon, Artifact.LogProc, Artifact.Archive, Artifact.Rosetta ]

let All = AllButTests # [ Artifact.FunctionalTestSuite ]

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "Daemon"
            , DaemonLegacyHardfork = "DaemonLegacyHardfork"
            , DaemonAutoHardfork = "DaemonAutoHardfork"
            , LogProc = "LogProc"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , BatchTxn = "BatchTxn"
            , Rosetta = "Rosetta"
            , ZkappTestTransaction = "ZkappTestTransaction"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , Toolchain = "Toolchain"
            , CreateLegacyGenesis = "CreateLegacyGenesis"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "daemon"
            , DaemonLegacyHardfork = "daemon_hardfork"
            , DaemonAutoHardfork = "daemon_auto_hardfork"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , CreateLegacyGenesis = "create_legacy_genesis"
            , Toolchain = "toolchain"
            }
            artifact

let dockerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "mina-daemon"
            , DaemonLegacyHardfork = "mina-daemon-hardfork"
            , DaemonAutoHardfork = "mina-daemon-auto-hardfork"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , LogProc = "mina-logproc"
            , BatchTxn = "mina-batch-txn"
            , Rosetta = "mina-rosetta"
            , ZkappTestTransaction = "mina-zkapp-test-transaction"
            , FunctionalTestSuite = "mina-test-suite"
            , Toolchain = "mina-toolchain"
            , CreateLegacyGenesis = "mina-create-legacy-genesis"
            }
            artifact

let dockerNames =
          \(artifacts : List Artifact)
      ->  Prelude.List.map
            Artifact
            Text
            (\(a : Artifact) -> dockerName a)
            artifacts

let toDebianNames =
          \(artifacts : List Artifact)
      ->  \(network : Network.Type)
      ->  \(profile : Profiles.Type)
      ->  let list_of_list_of_debians =
                Prelude.List.map
                  Artifact
                  (List Text)
                  (     \(a : Artifact)
                    ->  let pubnet_daemon_debs = [ "daemon_mainnet", "daemon_devnet", "daemon_base" ] in
                        merge
                          { Daemon =
                              merge
                                { Dev = [ "daemon_base" ]
                                , Lightnet = [ "daemon_base" ]
                                , PublicNetwork = pubnet_daemon_debs
                                }
                                profile
                          , DaemonLegacyHardfork = [ "daemon_${Network.lowerName network}" ]
                          , DaemonAutoHardfork = [ "" ]
                          , Archive = [ "archive" ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , BatchTxn = [ "batch_txn" ]
                          , Rosetta =
                              merge
                                { Base = [ "rosetta", "daemon_base" ]
                                , Devnet = [ "rosetta" ] # pubnet_daemon_debs
                                , Mainnet = [ "rosetta" ] # pubnet_daemon_debs
                                , Legacy = [ "rosetta" ] # pubnet_daemon_debs
                                }
                                network
                          , ZkappTestTransaction = [ "zkapp_test_transaction" ]
                          , FunctionalTestSuite = [ "functional_test_suite" ]
                          , CreateLegacyGenesis = [ "create_legacy_genesis" ]
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
          }
      , default =
          { artifact = Artifact.Daemon
          , version = "\\\${MINA_DOCKER_TAG}"
          , profile = Profiles.Type.PublicNetwork
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Base
          }
      }

let dockerTag =
          \(spec : Tag.Type)
      ->  let build_flags_part =
                merge
                  { None = ""
                  , Instrumented =
                      "${BuildFlags.toLabelSegment spec.buildFlags}"
                  }
                  spec.buildFlags

          in  merge
                { Daemon =
                    "${spec.version}-${Network.lowerName
                                         spec.network}${build_flags_part}"
                , DaemonLegacyHardfork =
                    "${spec.version}-${Network.lowerName
                                         spec.network}"
                , DaemonAutoHardfork =
                    "${spec.version}-${Network.lowerName
                                         spec.network}"
                , Archive = "${spec.version}${build_flags_part}"
                , LogProc = "${spec.version}"
                , TestExecutive = "${spec.version}"
                , BatchTxn = "${spec.version}"
                , Rosetta = "${spec.version}-${Network.lowerName spec.network}"
                , ZkappTestTransaction = "${spec.version}"
                , FunctionalTestSuite = "${spec.version}${build_flags_part}"
                , Toolchain = "${spec.version}"
                , CreateLegacyGenesis = "${spec.version}"
                }
                spec.artifact

let fullDockerTag =
          \(spec : Tag.Type)
      ->  "${Repo.show Repo.Type.Internal}/${dockerName
                                               spec.artifact}:${dockerTag spec}"

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
