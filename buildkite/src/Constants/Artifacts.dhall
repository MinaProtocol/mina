let Prelude = ../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let Profiles = ./Profiles.dhall

let Network = ./Network.dhall

let Repo = ./DockerRepo.dhall

let Artifact
    : Type
    = < Daemon
      | DaemonHardfork
      | LogProc
      | Archive
      | TestExecutive
      | BatchTxn
      | Rosetta
      | ZkappTestTransaction
      | FunctionalTestSuite
      | Toolchain
      >

let AllButTests =
      [ Artifact.Daemon
      , Artifact.DaemonHardfork
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.BatchTxn
      , Artifact.TestExecutive
      , Artifact.Rosetta
      , Artifact.ZkappTestTransaction
      , Artifact.Toolchain
      ]

let Main =
      [ Artifact.Daemon, Artifact.LogProc, Artifact.Archive, Artifact.Rosetta ]

let All =
        AllButTests
      # [ Artifact.FunctionalTestSuite
        , Artifact.Toolchain
        , Artifact.DaemonHardfork
        ]

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "Daemon"
            , DaemonHardfork = "DaemonHardfork"
            , LogProc = "LogProc"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , BatchTxn = "BatchTxn"
            , Rosetta = "Rosetta"
            , ZkappTestTransaction = "ZkappTestTransaction"
            , FunctionalTestSuite = "FunctionalTestSuite"
            , Toolchain = "Toolchain"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "daemon"
            , DaemonHardfork = "daemon_hardfork"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , Toolchain = "toolchain"
            }
            artifact

let dockerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "mina-daemon"
            , DaemonHardfork = "mina-daemon-hardfork"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , LogProc = "mina-logproc"
            , BatchTxn = "mina-batch-txn"
            , Rosetta = "mina-rosetta"
            , ZkappTestTransaction = "mina-zkapp-test-transaction"
            , FunctionalTestSuite = "mina-test-suite"
            , Toolchain = "mina-toolchain"
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
            , DaemonHardfork = ""
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta_${Network.lowerName network}"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            , Toolchain = ""
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
                          , DaemonHardfork = [ toDebianName a network ]
                          , Archive = [ "archive" ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , BatchTxn = [ "batch_txn" ]
                          , Rosetta = [ toDebianName a network ]
                          , ZkappTestTransaction = [ "zkapp_test_transaction" ]
                          , FunctionalTestSuite = [ "functional_test_suite" ]
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
          , remove_profile_from_name : Bool
          }
      , default =
          { artifact = Artifact.Daemon
          , version = "\\\${MINA_DOCKER_TAG}"
          , profile = Profiles.Type.Standard
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

          in  merge
                { Daemon =
                    "${spec.version}-${Network.lowerName
                                         spec.network}${profile_part}"
                , DaemonHardfork =
                    "${spec.version}-${Network.lowerName
                                         spec.network}${profile_part}"
                , Archive = "${spec.version}"
                , LogProc = "${spec.version}"
                , TestExecutive = "${spec.version}"
                , BatchTxn = "${spec.version}"
                , Rosetta = "${spec.version}-${Network.lowerName spec.network}"
                , ZkappTestTransaction = "${spec.version}"
                , FunctionalTestSuite = "${spec.version}"
                , Toolchain = "${spec.version}"
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
