let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Arch = ../../Constants/Arch.dhall

let Profiles = ../../Constants/Profiles.dhall

let Expr = ../../Pipeline/Expr.dhall

let MainlineBranch = ../../Pipeline/MainlineBranch.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.LogProc
            , Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , network = Network.Type.Mesa
          , arch = Arch.Type.Arm64
          , profile = Profiles.Type.Lightnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Mesa
            , PipelineTag.Type.Arm64
            , PipelineTag.Type.Bookworm
            , PipelineTag.Type.Lightnet
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          , includeIf =
            [ Expr.Type.DescendantOf
                { ancestor = MainlineBranch.Type.Mesa
                , reason = "Only run on Mesa descendants"
                }
            ]
          }
      )
