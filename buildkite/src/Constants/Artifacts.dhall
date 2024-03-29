let Prelude = ../External/Prelude.dhall
let Text/concatSep = Prelude.Text.concatSep
let Profiles = ./Profiles.dhall

let Artifact : Type  = < Daemon | Archive | ArchiveMigration | TestExecutive | BatchTxn | Rosetta | ZkappTestTransaction | FunctionalTestSuite | ArchiveMaintenance >

let AllButTests = [ Artifact.Daemon , Artifact.Archive , Artifact.ArchiveMigration , Artifact.BatchTxn , Artifact.TestExecutive , Artifact.Rosetta , Artifact.ZkappTestTransaction , ArchiveMaintenance ]

let Main = [ Artifact.Daemon , Artifact.Archive , Artifact.Rosetta ]

let All = AllButTests # [ Artifact.FunctionalTestSuite ]

let capitalName = \(artifact : Artifact) ->
  merge {
    Daemon = "Daemon"
    , Archive = "Archive"
    , ArchiveMigration = "ArchiveMigration"
    , ArchiveMaintenance = "ArchiveMaintenance"
    , TestExecutive = "TestExecutive"
    , BatchTxn = "BatchTxn"
    , Rosetta = "Rosetta"
    , ZkappTestTransaction = "ZkappTestTransaction"
    , FunctionalTestSuite = "FunctionalTestSuite"
  } artifact

let lowerName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , ArchiveMigration = "archive_migration"
    , ArchiveMaintenance = "archive_maintenance"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "rosetta"
    , ZkappTestTransaction = "zkapp_test_transaction"
    , FunctionalTestSuite = "functional_test_suite"
  } artifact

let dockerName = \(artifact : Artifact) ->
  merge {
    Daemon = "mina-daemon"
    , Archive = "mina-archive"
    , TestExecutive = "mina-test-executive"
    , ArchiveMigration = "mina-archive-migration"
    , ArchiveMaintenance = "mina-archive-maintenance"
    , BatchTxn = "mina-batch-txn"
    , Rosetta = "mina-rosetta" 
    , ZkappTestTransaction = "mina-zkapp-test-transaction"
    , FunctionalTestSuite = "mina-test-suite"
  } artifact


let toDebianName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , ArchiveMigration  = "archive_migration"
    , ArchiveMaintenance = ""
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "" 
    , ZkappTestTransaction = "zkapp_test_transaction"
    , FunctionalTestSuite = "functional_test_suite"
  } artifact

let toDebianNames = \(artifacts : List Artifact) -> 
    let text = Prelude.List.map
        Artifact
        Text
        (\(a: Artifact) ->  toDebianName a )
        artifacts
    in      
    Text/concatSep " " text
in

{
  Type = Artifact
  , capitalName = capitalName
  , lowerName = lowerName
  , toDebianName = toDebianName
  , toDebianNames = toDebianNames
  , dockerName = dockerName
  , All = All 
  , AllButTests = AllButTests 
  , Main = Main
}