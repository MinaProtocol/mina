let Package : Type  = < Daemon | DaemonLightnet | Archive | ArchiveMigration | TestExecutive | BatchTxn | LogProc | ZkappTestTransaction | FunctionalTestSuite >

let MainPackages = [ Package.Daemon , Package.Archive , Package.ArchiveMigration , Package.LogProc ]

let AuxiliaryPackages = [ Package.DaemonLightnet , Package.TestExecutive , Package.BatchTxn , Package.ZkappTestTransaction , Package.FunctionalTestSuite ]


let capitalName = \(package : Package) ->
  merge {
    Daemon = "Daemon"
    , DaemonLightnet = "DaemonLightnet"
    , Archive = "Archive"
    , ArchiveMigration = "ArchiveMigration"
    , TestExecutive = "TestExecutive"
    , BatchTxn = "BatchTxn"
    , LogProc = "Logproc"
    , ZkappTestTransaction = "ZkappTestTransaction"
    , FunctionalTestSuite = "FunctionalTestSuite"
  } package

let lowerName = \(package : Package) ->
  merge {
    Daemon = "daemon"
    , DaemonLightnet = "daemon_lightnet"
    , Archive = "archive"
    , ArchiveMigration = "archive_migration"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , LogProc = "logproc"
    , ZkappTestTransaction = "zkapp_test_transaction"
    , FunctionalTestSuite = "functional_test_suite"
  } package

let debianName = \(package : Package) ->
  merge {
    Daemon = "mina-berkeley"
    , DaemonLightnet = "mina-berkeley-lightnet"
    , Archive = "mina-archive"
    , ArchiveMigration = "mina-archive-berkeley-archive-migration"
    , TestExecutive = "mina-test-executive"
    , BatchTxn = "mina-batch-txn"
    , LogProc = "mina-logproc" 
    , ZkappTestTransaction = "mina-zkapp-test-transaction"
    , FunctionalTestSuite = "mina-test-suite"
  } package

in
{
  Type = Package
  , MainPackages = MainPackages
  , AuxiliaryPackages = AuxiliaryPackages
  , capitalName = capitalName
  , lowerName = lowerName
  , debianName = debianName 
}