let Network = ./Network.dhall

let Profile = ./Profiles.dhall

let Package
    : Type
    = < Daemon
      | Archive
      | Rosetta
      | TestExecutive
      | TxTools
      | LogProc
      | FunctionalTestSuite
      >

let MainPackages =
      [ Package.Daemon, Package.Archive, Package.LogProc, Package.Rosetta ]

let AuxiliaryPackages =
      [ Package.TestExecutive, Package.TxTools, Package.FunctionalTestSuite ]

let capitalName =
          \(package : Package)
      ->  merge
            { Daemon = "Daemon"
            , Archive = "Archive"
            , TestExecutive = "TestExecutive"
            , TxTools = "TxTools"
            , LogProc = "Logproc"
            , Rosetta = "Rosetta"
            , FunctionalTestSuite = "FunctionalTestSuite"
            }
            package

let lowerName =
          \(package : Package)
      ->  merge
            { Daemon = "daemon"
            , Archive = "archive"
            , TestExecutive = "test_executive"
            , TxTools = "tx_tools"
            , LogProc = "logproc"
            , Rosetta = "rosetta"
            , FunctionalTestSuite = "functional_test_suite"
            }
            package

let debianName =
          \(package : Package)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  merge
            { Daemon =
                "mina-${Network.lowerName network}${Profile.toLabelSegment
                                                      profile}"
            , Rosetta =
                "mina--rosetta-${Network.lowerName
                                   network}${Profile.toLabelSegment profile}"
            , Archive = "mina-archive"
            , TestExecutive = "mina-test-executive"
            , TxTools = "mina-tx-tools"
            , LogProc = "mina-logproc"
            , FunctionalTestSuite = "mina-test-suite"
            }
            package

in  { Type = Package
    , MainPackages = MainPackages
    , AuxiliaryPackages = AuxiliaryPackages
    , capitalName = capitalName
    , lowerName = lowerName
    , debianName = debianName
    }
