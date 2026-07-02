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
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Devnet }
            , Artifacts.Type.Daemon { network = Network.Type.Mainnet }
            , Artifacts.Type.DaemonGeneric
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Lightnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Devnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Mainnet }
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
          , arch = Arch.Type.Arm64
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Arm64
            , PipelineTag.Type.Bookworm
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
