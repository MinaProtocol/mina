-- arm64 variant of the dedicated, scope-isolated mina-bootstrap release
-- pipeline. See MinaArtifactBootstrapBookworm.dhall (amd64) for the
-- rationale: gated to the BootstrapRelease scope + Bootstrap tag so it runs only
-- when triggered with the BootstrapOnly scope filter, never on PR/Nightly.

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      ( ArtifactPipelines.bootstrapPipeline
          ArtifactPipelines.PackagingSpec::{
          , artifacts = [ Artifacts.Type.MinaBootstrap ]
          , channel = DebianChannel.Type.Experimental
          , debVersion = DebianVersions.DebVersion.Bookworm
          , arch = Arch.Type.Arm64
          , tags =
            [ PipelineTag.Type.Bootstrap
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Debian
            , PipelineTag.Type.Bookworm
            , PipelineTag.Type.Arm64
            ]
          , scope = [ PipelineScope.Type.BootstrapRelease ]
          , prefix = "MinaArtifactBootstrap"
          }
      )
