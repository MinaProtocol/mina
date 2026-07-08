let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

in  Pipeline.build
      ( ArtifactPipelines.packagePipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Mainnet }
            , Artifacts.Type.DaemonAutoHardfork
                { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonPrefork { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonPostfork { network = Network.Type.Mainnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Mainnet }
            , Artifacts.Type.Archive { network = Network.Type.Mainnet }
            , Artifacts.Type.Rosetta { network = Network.Type.Mainnet }
            ]
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
