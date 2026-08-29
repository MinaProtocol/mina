let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let Arch = ../../Constants/Arch.dhall

in  Pipeline.build
      ( ArtifactPipelines.dockerPipeline
          ArtifactPipelines.PackagingSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Mainnet }
            , Artifacts.Type.DaemonPrefork { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonPostfork { network = Network.Type.Mainnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Mainnet }
            , Artifacts.Type.Archive { network = Network.Type.Mainnet }
            , Artifacts.Type.Rosetta { network = Network.Type.Mainnet }
            ]
          , arch = Arch.Type.Arm64
          , tags =
            [ PipelineTag.Type.Packaging
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Arm64
            , PipelineTag.Type.Bookworm
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , scope = [ PipelineScope.Type.Weekly, PipelineScope.Type.Release ]
          }
      )
