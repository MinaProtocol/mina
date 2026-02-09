let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Profiles = ../../Constants/Profiles.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonAutoHardfork
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.PreforkGenesisLedger
            , Artifacts.Type.PreforkDaemon
            ]
          , debVersion = DebianVersions.DebVersion.Focal
          , network = Network.Type.Mainnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Stable
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Focal
            ]
          , profile = Profiles.Type.Mainnet
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
