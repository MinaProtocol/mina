let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Profile = ../../Constants/Profiles.dhall

let Network = ../../Constants/Network.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Devnet }
            , Artifacts.Type.Daemon { network = Network.Type.Mainnet }
            , Artifacts.Type.Daemon { network = Network.Type.MesaMut }
            , Artifacts.Type.DaemonGeneric
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Lightnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Devnet }
            , Artifacts.Type.DaemonProfiled { profile = Profile.Type.Mainnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Devnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.Mainnet }
            , Artifacts.Type.CreatePreforkGenesis
                { network = Network.Type.MesaMut }
            , Artifacts.Type.Archive { network = Network.Type.Devnet }
            , Artifacts.Type.Archive { network = Network.Type.Mainnet }
            , Artifacts.Type.Archive { network = Network.Type.MesaMut }
            , Artifacts.Type.Rosetta { network = Network.Type.Devnet }
            , Artifacts.Type.Rosetta { network = Network.Type.Mainnet }
            , Artifacts.Type.Rosetta { network = Network.Type.MesaMut }
            , Artifacts.Type.LogProc
            , Artifacts.Type.TxTools
            , Artifacts.Type.FunctionalTestSuite
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , buildFlags = BuildFlags.Type.Instrumented
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
