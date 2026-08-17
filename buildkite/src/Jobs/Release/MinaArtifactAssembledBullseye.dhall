-- The single-agent shape of MinaArtifactBullseye: the same artifacts, built by
-- one step on one agent instead of an app job, a packaging job and a step per
-- image.
--
-- It is opt-in and is selected by nothing: `scope = []` keeps it out of pull
-- request CI, out of the nightlies and out of the release pipeline, which all
-- keep the fan-out. Run it by name with `!ci-single-me
-- MinaArtifactAssembledBullseye`.
--
-- The artifact list is MinaArtifactBullseye's, less TestExecutive and
-- FunctionalTestSuite, which produce no image and no package that any image
-- installs.

let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

in  Pipeline.build
      ( ArtifactPipelines.assembledPipeline
          ArtifactPipelines.PackagingSpec::{
          , prefix = "MinaArtifactAssembled"
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonGeneric
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Lightnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Devnet }
            , Artifacts.Type.DaemonAutoHardfork
                { network = Network.Type.Devnet }
            , Artifacts.Type.ArchiveGeneric
            , Artifacts.Type.Archive { network = Network.Type.Devnet }
            , Artifacts.Type.RosettaGeneric
            , Artifacts.Type.Rosetta { network = Network.Type.Devnet }
            , Artifacts.Type.LogProc
            , Artifacts.Type.TxTools
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , scope = [] : List PipelineScope.Type
          , tags =
            [ PipelineTag.Type.Packaging
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
