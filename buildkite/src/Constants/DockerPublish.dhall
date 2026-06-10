let Artifacts = ./Artifacts.dhall

let DockerPublish
    : Type
    = < Enabled | Disabled | Essential >

let isEssential =
          \(service : Artifacts.Type)
      ->  merge
            { DaemonConfig = True
            , DaemonPrefork = True
            , DaemonAppsOnly = True
            , LogProc = False
            , Archive = True
            , TestExecutive = False
            , BatchTxn = False
            , Rosetta = True
            , RosettaAppsOnly = True
            , RosettaConfig = True
            , ZkappTestTransaction = False
            , FunctionalTestSuite = True
            , Toolchain = True
            , DaemonAutoHardfork = True
            , DaemonAutomode = False
            , DaemonLegacyHardfork = True
            , CreatePreforkGenesis = False
            , DelegationVerifier = True
            , DaemonStorageToolbox = False
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
