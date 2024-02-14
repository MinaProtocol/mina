let Prelude = ../External/Prelude.dhall
let Text/concatSep = Prelude.Text.concatSep
let Profiles = ./Profiles.dhall

let Artifact : Type  = < Daemon | Archive | TestExecutive | BatchTxn | Rosetta | ZkappTestTransaction | TestSuite >

let All = [ Artifact.Daemon , Artifact.Archive , Artifact.TestExecutive , Artifact.BatchTxn , Artifact.Rosetta , Artifact.ZkappTestTransaction, Artifact.TestSuite ]

let AllButTests = [ Artifact.Daemon , Artifact.Archive , Artifact.BatchTxn , Artifact.TestExecutive , Artifact.Rosetta , Artifact.ZkappTestTransaction ]


let capitalName = \(artifact : Artifact) ->
  merge {
    Daemon = "Daemon"
    , Archive = "Archive"
    , TestExecutive = "TestExecutive"
    , BatchTxn = "BatchTxn"
    , Rosetta = "Rosetta"
    , ZkappTestTransaction = "ZkappTestTransaction"
    , TestSuite = "TestSuite"
  } artifact

let lowerName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "rosetta"
    , ZkappTestTransaction = "zkapp_test_transaction"
    , TestSuite = "test_suite"
  } artifact


let toDebianName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "" 
    , ZkappTestTransaction = "zkapp_test_transaction"
    , TestSuite = "test_suite"
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
  , AllButTests = AllButTests 
}