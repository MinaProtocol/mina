let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.RosettaConfig
            , Artifacts.Type.RosettaAppsOnly
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , network = Network.Type.MesaMut
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Focal
            ]
          , debVersion = DebianVersions.DebVersion.Focal
          }
      )
