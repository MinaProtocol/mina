let Package : Type  = < Daemon | DaemonDevnet | DaemonLightnet | Archive | ArchiveMigration | CreateLegacyGenesis| TestExecutive | BatchTxn | LogProc | ZkappTestTransaction | FunctionalTestSuite >

let MainPackages = [ Package.Daemon , Package.DaemonDevnet , Package.Archive , Package.ArchiveMigration , Package.LogProc ]

let AuxiliaryPackages = [ Package.DaemonLightnet , Package.TestExecutive , Package.BatchTxn , Package.ZkappTestTransaction , Package.FunctionalTestSuite , Package.CreateLegacyGenesis ]


let capitalName = \(package : Package) ->
  merge {
    Daemon = "Daemon"
    , DaemonDevnet = "DaemonDevnet"
    , DaemonLightnet = "DaemonLightnet"
    , Archive = "Archive"
    , ArchiveMigration = "ArchiveMigration"
    , CreateLegacyGenesis = "CreateLegacyGenesis"
    , TestExecutive = "TestExecutive"
    , BatchTxn = "BatchTxn"
    , LogProc = "Logproc"
    , ZkappTestTransaction = "ZkappTestTransaction"
    , FunctionalTestSuite = "FunctionalTestSuite"
  } package

let lowerName = \(package : Package) ->
  merge {
    Daemon = "daemon"
    , DaemonDevnet = "daemon_devnet"
    , DaemonLightnet = "daemon_lightnet"
    , Archive = "archive"
    , ArchiveMigration = "archive_migration"
    , CreateLegacyGenesis = "create_legacy_genesis"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , LogProc = "logproc"
    , ZkappTestTransaction = "zkapp_test_transaction"
    , FunctionalTestSuite = "functional_test_suite"
  } package

let debianName = \(package : Package) ->
  merge {
    Daemon = "mina-berkeley"
    , DaemonDevnet = "mina-devnet"
    , DaemonLightnet = "mina-berkeley-lightnet"
    , Archive = "mina-archive"
    , ArchiveMigration = "mina-archive-migration"
    , CreateLegacyGenesis = "mina-create-legacy-genesis"
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