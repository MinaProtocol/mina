let Artifacts = ./Artifacts.dhall

let DockerPublish
    : Type
    = < Enabled | Disabled | Essential >

let isEssential =
          \(service : Artifacts.Type)
      ->  merge
            { Daemon = True
            , DaemonConfig = False
            , LogProc = False
            , Archive = True
            , TestExecutive = False
            , BatchTxn = False
            , Rosetta = True
            , ZkappTestTransaction = False
            , FunctionalTestSuite = True
            , Toolchain = True
            , DaemonAutoHardfork = True
            , DaemonLegacyHardfork = True
            , PreforkDaemon = False
            , PreforkGenesisLedger = False
            , DelegationVerifier = True
            }
            service

let shouldPublish =
          \(publish : DockerPublish)
      ->  \(service : Artifacts.Type)
      ->  merge
            { Disabled = False
            , Enabled = True
            , Essential = isEssential service
            }
            publish

let show =
          \(publish : DockerPublish)
      ->  merge
            { Enabled = "Enabled"
            , Disabled = "Disabled"
            , Essential = "Essential"
            }
            publish

in  { Type = DockerPublish
    , shouldPublish = shouldPublish
    , isEssential = isEssential
    , show = show
    }
