let Prelude = ../External/Prelude.dhall
let Text/concatSep = Prelude.Text.concatSep
let Profiles = ./Profiles.dhall

let Artifact : Type  = < Daemon | Archive | TestExecutive | BatchTxn | Rosetta | ZkappTestTransaction >

let All = [ Artifact.Daemon , Artifact.Archive , Artifact.TestExecutive , Artifact.BatchTxn , Artifact.Rosetta , Artifact.ZkappTestTransaction ]
   
let capitalName = \(artifact : Artifact) ->
  merge {
    Daemon = "Daemon"
    , Archive = "Archive"
    , TestExecutive = "TestExecutive"
    , BatchTxn = "BatchTxn"
    , Rosetta = "Rosetta"
    , ZkappTestTransaction = "ZkappTestTransaction"
  } artifact

let lowerName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "rosetta"
    , ZkappTestTransaction = "zkapp_test_transaction"
  } artifact


let toDebianName = \(artifact : Artifact) ->
  merge {
    Daemon = "daemon"
    , Archive = "archive"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , Rosetta = "" 
    , ZkappTestTransaction = "zkapp_test_transaction"
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