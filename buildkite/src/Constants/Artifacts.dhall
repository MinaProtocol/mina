let Prelude = ../External/Prelude.dhall

let Text/concatSep = Prelude.Text.concatSep

let Profiles = ./Profiles.dhall

let DebianVersions = ./DebianVersions.dhall

let Network = ./Network.dhall

let Artifact
    : Type
    = < Daemon
      | Archive
      | ArchiveMigration
      | TestExecutive
      | BatchTxn
      | Rosetta
      | ZkappTestTransaction
      | FunctionalTestSuite
      >

let AllButTests =
      [ Artifact.Daemon
      , Artifact.Archive
      , Artifact.ArchiveMigration
      , Artifact.BatchTxn
      , Artifact.TestExecutive
      , Artifact.Rosetta
      , Artifact.ZkappTestTransaction
      ]

let Main = [ Artifact.Daemon, Artifact.Archive, Artifact.Rosetta ]

let All = AllButTests # [ Artifact.FunctionalTestSuite ]

let capitalName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "Daemon"
            , Archive = "Archive"
            , ArchiveMigration = "ArchiveMigration"
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
            , Archive = "archive"
            , ArchiveMigration = "archive_migration"
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
            , ArchiveMigration = "mina-archive-migration"
            , BatchTxn = "mina-batch-txn"
            , Rosetta = "mina-rosetta"
            , ZkappTestTransaction = "mina-zkapp-test-transaction"
            , FunctionalTestSuite = "mina-test-suite"
            }
            artifact

let toDebianName =
          \(artifact : Artifact)
      ->  merge
            { Daemon = "daemon"
            , Archive = "archive"
            , ArchiveMigration = "archive_migration"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , Rosetta = ""
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            }
            artifact

let toDebianNames =
          \(artifacts : List Artifact)
      ->  let text =
                Prelude.List.map
                  Artifact
                  Text
                  (\(a : Artifact) -> toDebianName a)
                  artifacts

          in  Text/concatSep " " text

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
                , ArchiveMigration = "${version_and_codename}"
                , TestExecutive = "${version_and_codename}"
                , BatchTxn = "${version_and_codename}"
                , Rosetta = "${version_and_codename}"
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
