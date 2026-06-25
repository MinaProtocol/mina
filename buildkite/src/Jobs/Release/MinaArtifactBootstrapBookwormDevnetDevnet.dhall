-- Dedicated, scope-isolated release pipeline for the mina-bootstrap CLI.
--
-- mina-bootstrap is a standalone Go tool with its own release cadence; it does
-- not need to be rebuilt on every PR / nightly alongside the daemon. This job is
-- gated to the BootstrapRelease scope (see Pipeline/Scope.dhall) and the
-- Bootstrap tag, so it runs ONLY when a pipeline is triggered with the
-- BootstrapOnly scope filter (`./buildkite/scripts/monorepo.sh --scopes
-- bootstraprelease ...`) -- never on PullRequest, Nightly, Weekly or Release.
--
-- It builds just the lightweight .deb (the Go binary, no OCaml daemon) and the
-- self-contained Docker image.

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      ( ArtifactPipelines.bootstrapPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts = [ Artifacts.Type.MinaBootstrap ]
          , network = Network.Type.Devnet
          , channel = DebianChannel.Type.Experimental
          , debVersion = DebianVersions.DebVersion.Bookworm
          , tags =
            [ PipelineTag.Type.Bootstrap
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Debian
            , PipelineTag.Type.Bookworm
            , PipelineTag.Type.Amd64
            ]
          , scope = [ PipelineScope.Type.BootstrapRelease ]
          , prefix = "MinaArtifactBootstrap"
          }
      )
