let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

in  Pipeline.build
      ( ArtifactPipelines.appsPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonGeneric
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Lightnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Devnet }
            , Artifacts.Type.DaemonAutoHardfork
                { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonPrefork { network = Network.Type.Devnet }
            , Artifacts.Type.DaemonPostfork { network = Network.Type.Devnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Devnet }
            , Artifacts.Type.ArchiveGeneric
            , Artifacts.Type.Archive { network = Network.Type.Devnet }
            , Artifacts.Type.RosettaGeneric
            , Artifacts.Type.Rosetta { network = Network.Type.Devnet }
            , Artifacts.Type.LogProc
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.TxTools
            , Artifacts.Type.DaemonStorageToolbox
            , Artifacts.Type.FunctionalTestSuite
            ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
