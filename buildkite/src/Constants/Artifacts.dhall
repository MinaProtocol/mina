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
      ->  let list_of_list_of_debians =
                Prelude.List.map
                  Artifact
                  (List Text)
                  (     \(a : Artifact)
                    ->  merge
                          { Daemon = [ "daemon_${Network.lowerName network}" ]
                          , DaemonLegacyHardfork = [ "daemon_${Network.lowerName network}_hardfork" ]
                          , DaemonAutoHardfork = [ "" ]
                          , Archive = [ "archive" ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , BatchTxn = [ "batch_txn" ]
                          , Rosetta = [ "rosetta" ]
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
          , remove_profile_from_name : Bool
          }
      , default =
          { artifact = Artifact.Daemon
          , version = "\\\${MINA_DOCKER_TAG}"
          , profile = Profiles.Type.PublicNetwork
          , buildFlags = BuildFlags.Type.None
          , network = Network.Type.Berkeley
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
                    "${spec.version}-${Network.lowerName
                                         spec.network}${profile_part}${build_flags_part}"
                , DaemonLegacyHardfork =
                    "${spec.version}-${Network.lowerName
                                         spec.network}${profile_part}"
                , DaemonAutoHardfork =
                    "${spec.version}-${Network.lowerName
                                         spec.network}${profile_part}"
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
