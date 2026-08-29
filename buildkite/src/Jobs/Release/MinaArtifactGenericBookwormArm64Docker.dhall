let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      ( ArtifactPipelines.dockerPipeline
          ArtifactPipelines.PackagingSpec::{
          , artifacts =
            [ Artifacts.Type.DaemonGeneric
            , Artifacts.Type.ArchiveGeneric
            , Artifacts.Type.RosettaGeneric
            , Artifacts.Type.LogProc
            , Artifacts.Type.TxTools
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , generic = True
          , arch = Arch.Type.Arm64
          , tags =
            [ PipelineTag.Type.Packaging
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Arm64
            , PipelineTag.Type.Bookworm
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , scope = [ PipelineScope.Type.Weekly, PipelineScope.Type.Release ]
          }
      )
