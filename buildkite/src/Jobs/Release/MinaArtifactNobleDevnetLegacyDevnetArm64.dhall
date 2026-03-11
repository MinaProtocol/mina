let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      ( ArtifactPipelines.onlyDebianPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonRecoveryStorageToolbox
            ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            ]
          , network = Network.Type.DevnetLegacy
          , arch = Arch.Type.Arm64
          , debVersion = DebianVersions.DebVersion.Noble
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
