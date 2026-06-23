let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.DaemonPrefork
            , Artifacts.Type.DaemonAutoHardfork
            , Artifacts.Type.DaemonAutomode
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.RosettaConfig
            , Artifacts.Type.TxTools
            , Artifacts.Type.RosettaAppsOnly
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.DelegationVerifier
            , Artifacts.Type.DaemonStorageToolbox
            , Artifacts.Type.MinaBootstrap
            ]
          , network = Network.Type.Devnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bookworm
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , scope = [ PipelineScope.Type.Weekly, PipelineScope.Type.Release ]
          }
      )
