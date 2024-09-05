let Prelude = ../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let Profiles = ./Profiles.dhall

let DebianVersions = ./DebianVersions.dhall

let Network = ./Network.dhall

let Artifact
    : Type
    = < Daemon
      | LogProc
      | Archive
      | TestExecutive
      | BatchTxn
      | Rosetta
      | ZkappTestTransaction
      | FunctionalTestSuite
      >

let AllButTests =
      [ Artifact.Daemon
      , Artifact.LogProc
      , Artifact.Archive
      , Artifact.BatchTxn
      , Artifact.TestExecutive
      , Artifact.Rosetta
      , Artifact.ZkappTestTransaction
      ]

let Main =
      [ Artifact.Daemon, Artifact.LogProc, Artifact.Archive, Artifact.Rosetta ]

let All = AllButTests # [ Artifact.FunctionalTestSuite ]

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "Daemon"
            , LogProc = "LogProc"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , BatchTxn = "BatchTxn"
            , Rosetta = "Rosetta"
            , ZkappTestTransaction = "ZkappTestTransaction"
            , FunctionalTestSuite = "FunctionalTestSuite"
            }
            artifact

let lowerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "daemon"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            }
            artifact

let dockerName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "mina-daemon"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , LogProc = "mina-logproc"
            , BatchTxn = "mina-batch-txn"
            , Rosetta = "mina-rosetta"
            , ZkappTestTransaction = "mina-zkapp-test-transaction"
            , FunctionalTestSuite = "mina-test-suite"
            }
            artifact

let toDebianName =
          \(artifact : Artifact)
      ->  \(network : Network.Type)
      ->  merge
            { Daemon = "daemon_${Network.lowerName network}"
            , LogProc = "logproc"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = "rosetta_${Network.lowerName network}"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            }
            artifact

let toDebianNames =
          \(artifacts : List Artifact)
      ->  \(networks : List Network.Type)
      ->  let list_of_list_of_debians =
                Prelude.List.map
                  Artifact
                  (List Text)
                  (     \(a : Artifact)
                    ->  merge
                          { Daemon =
                              Prelude.List.map
                                Network.Type
                                Text
                                (\(n : Network.Type) -> toDebianName a n)
                                networks
                          , Archive = [ "archive" ]
                          , LogProc = [ "logproc" ]
                          , TestExecutive = [ "test_executive" ]
                          , BatchTxn = [ "batch_txn" ]
                          , Rosetta =
                              Prelude.List.map
                                Network.Type
                                Text
                                (     \(n : Network.Type)
                                  ->  "rosetta_${Network.lowerName n}"
                                )
                                networks
                          , ZkappTestTransaction = [ "zkapp_test_transaction" ]
                          , FunctionalTestSuite = [ "functional_test_suite" ]
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

let dockerTag =
          \(artifact : Artifact)
      ->  \(version : Text)
      ->  \(codename : DebianVersions.DebVersion)
      ->  \(profile : Profiles.Type)
      ->  \(network : Network.Type)
      ->  \(remove_profile_from_name : Bool)
      ->  let version_and_codename =
                "${version}-${DebianVersions.lowerName codename}"

          let profile_part =
                      if remove_profile_from_name

                then  ""

                else  "${Profiles.toLabelSegment profile}"

          in  merge
                { Daemon =
                    "${version_and_codename}-${Network.lowerName
                                                 network}${profile_part}"
                , Archive = "${version_and_codename}"
                , LogProc = "${version_and_codename}"
                , TestExecutive = "${version_and_codename}"
                , BatchTxn = "${version_and_codename}"
                , Rosetta =
                    "${version_and_codename}-${Network.lowerName network}"
                , ZkappTestTransaction = "${version_and_codename}"
                , FunctionalTestSuite = "${version_and_codename}"
                }
                artifact

in  { Type = Artifact
    , capitalName = capitalName
    , lowerName = lowerName
    , toDebianName = toDebianName
    , toDebianNames = toDebianNames
    , dockerName = dockerName
    , dockerTag = dockerTag
    , All = All
    , AllButTests = AllButTests
    , Main = Main
    }
