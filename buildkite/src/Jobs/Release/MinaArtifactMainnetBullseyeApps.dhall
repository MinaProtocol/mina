-- NOTE: this job compiles exactly what MinaArtifactBullseyeApps compiles, and
-- writes to the SAME apps cache (`write_to_cache.sh bullseye`) -- the cache
-- variant is keyed on codename/arch/build-flags only, never on network. It is
-- kept for now purely so the consumers that name it keep resolving; collapsing
-- the two is a follow-up.
let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

in  Pipeline.build
      ( ArtifactPipelines.appsPipeline
          ArtifactPipelines.AppsSpec::{
          , nameSegment = "Mainnet"
          , debVersion = DebianVersions.DebVersion.Bullseye
          , scope = PipelineScope.AllButPullRequest
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
