let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Devnet }
            , Artifacts.Type.Daemon { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonGeneric
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Lightnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Devnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Mainnet }
            , Artifacts.Type.DaemonAutoHardfork
                { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonAutoHardfork
                { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonPrefork { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonPostfork { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonPrefork { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonPostfork { network = Network.Type.Mainnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Devnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Mainnet }
            , Artifacts.Type.ArchiveGeneric
            , Artifacts.Type.Archive { network = Network.Type.Devnet }
            , Artifacts.Type.Archive { network = Network.Type.Mainnet }
            , Artifacts.Type.RosettaGeneric
            , Artifacts.Type.Rosetta { network = Network.Type.Devnet }
            , Artifacts.Type.Rosetta { network = Network.Type.Mainnet }
            , Artifacts.Type.LogProc
            , Artifacts.Type.TxTools
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , scope = [ PipelineScope.Type.Weekly, PipelineScope.Type.Release ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Focal
            ]
          , debVersion = DebianVersions.DebVersion.Focal
          }
      )
