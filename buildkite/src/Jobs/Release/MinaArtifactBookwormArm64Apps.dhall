let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      ( ArtifactPipelines.appsPipeline
          ArtifactPipelines.AppsSpec::{
          , debVersion = DebianVersions.DebVersion.Bookworm
          , arch = Arch.Type.Arm64
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Arm64
            , PipelineTag.Type.Bookworm
            ]
          , scope = [ PipelineScope.Type.Weekly, PipelineScope.Type.Release ]
          }
      )
