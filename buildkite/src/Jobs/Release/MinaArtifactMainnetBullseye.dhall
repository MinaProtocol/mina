let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall
let Profiles = ../../Constants/Profiles.dhall
let Network = ../../Constants/Network.dhall
let Artifacts = ../../Constants/Artifacts.dhall
let Toolchain = ../../Constants/Toolchain.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

in

Pipeline.build 
    (ArtifactPipelines.pipeline 
        ArtifactPipelines.MinaBuildSpec::{
            artifacts = [ Artifacts.Type.Daemon , Artifacts.Type.Archive, Artifacts.Type.BatchTxn,
                        Artifacts.Type.Rosetta , Artifacts.Type.ZkappTestTransaction ],
            networks = [ Network.Type.Devnet, Network.Type.Mainnet ],
            additionalTags = [ PipelineTag.Type.Stable ]
        }
    )