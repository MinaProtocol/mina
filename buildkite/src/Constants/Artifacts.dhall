let Prelude = ../External/Prelude.dhall
let Text/concatSep = Prelude.Text.concatSep
let Profiles = ./Profiles.dhall

let Artifact : Type  = < Daemon | Archive | ArchiveMigration | TestExecutive | BatchTxn | Rosetta | ZkappTestTransaction | FunctionalTestSuite >

let All = [ Artifact.Daemon , Artifact.Archive , Artifact.ArchiveMigration ,Artifact.BatchTxn , Artifact.TestExecutive , Artifact.Rosetta , Artifact.ZkappTestTransaction, Artifact.FunctionalTestSuite ]

let capitalName = \(artifact : Artifact) ->
  merge {
    Daemon = "Daemon"
    , Archive = "Archive"
    , ArchiveMigration = "ArchiveMigration"
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
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "rosetta"
    , ZkappTestTransaction = "zkapp_test_transaction"
    , FunctionalTestSuite = "functional_test_suite"
  } artifact



let toDebianName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , ArchiveMigration  = "archive_migration"
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
  , All = All
}