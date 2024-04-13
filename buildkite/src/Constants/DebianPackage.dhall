let Network = ./Network.dhall
let Profile = ./Profiles.dhall

let Package : Type  = < Daemon |  Archive | ArchiveMigration | ArchiveMaintenance | TestExecutive | BatchTxn | LogProc | ZkappTestTransaction | FunctionalTestSuite >

let MainPackages = [ Package.Daemon , Package.Archive , Package.ArchiveMigration , Package.LogProc ]

let AuxiliaryPackages = [  Package.TestExecutive , Package.BatchTxn , Package.ZkappTestTransaction , Package.FunctionalTestSuite , Package.ArchiveMaintenance ]


let capitalName = \(package : Package) ->
  merge {
    Daemon = "Daemon"
    , Archive = "Archive"
    , ArchiveMaintenance = "ArchiveMaintenance" 
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
    , Archive = "archive"
    , ArchiveMaintenance = "archive_maintenance" 
    , ArchiveMigration = "archive_migration"
    , TestExecutive = "test_executive"
    , BatchTxn = "batch_txn"
    , LogProc = "logproc"
    , ZkappTestTransaction = "zkapp_test_transaction"
    , FunctionalTestSuite = "functional_test_suite"
  } package

let debianName = \(package : Package) -> \(profile : Profile.Type) -> \(network : Network.Type) ->
  merge {
    Daemon = "mina-${Network.lowerName network}${Profile.toLabelSegment profile}"
    , Archive = "mina-archive"
    , ArchiveMigration = "mina-archive-migration"
    , ArchiveMaintenance = "mina-archive-maintenance" 
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