let Network = ./Network.dhall

let Profile = ./Profiles.dhall

let Package
    : Type
    = < Daemon
      | Archive
      | Rosetta
      | TestExecutive
      | BatchTxn
      | LogProc
      | ZkappTestTransaction
      | FunctionalTestSuite
      >

let MainPackages =
      [ Package.Daemon, Package.Archive, Package.LogProc, Package.Rosetta ]

let AuxiliaryPackages =
      [ Package.TestExecutive
      , Package.BatchTxn
      , Package.ZkappTestTransaction
      , Package.FunctionalTestSuite
      ]

let capitalName =
          \(package : Package)
      ->  merge
            { Daemon = "Daemon"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , BatchTxn = "BatchTxn"
            , LogProc = "Logproc"
            , Rosetta = "Rosetta"
            , ZkappTestTransaction = "ZkappTestTransaction"
            , FunctionalTestSuite = "FunctionalTestSuite"
            }
            package

let lowerName =
          \(package : Package)
      ->  merge
            { Daemon = "daemon"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , BatchTxn = "batch_txn"
            , LogProc = "logproc"
            , Rosetta = "rosetta"
            , ZkappTestTransaction = "zkapp_test_transaction"
            , FunctionalTestSuite = "functional_test_suite"
            }
            package

in  { Type = Package
    , MainPackages = MainPackages
    , AuxiliaryPackages = AuxiliaryPackages
    , capitalName = capitalName
    , lowerName = lowerName
    }
