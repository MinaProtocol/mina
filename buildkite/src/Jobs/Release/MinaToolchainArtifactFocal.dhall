let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts = [ Artifacts.Type.Toolchain ]
          , tags = [ PipelineTag.Type.Toolchain ]
          , prefix = "MinaToolchainArtifact"
          , debVersion = DebianVersions.DebVersion.Focal
          }
      )
