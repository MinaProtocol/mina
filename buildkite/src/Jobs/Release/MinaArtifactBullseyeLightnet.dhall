let ArtifactPipelines = ../../Command/MinaArtifact.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let Profiles = ../../Constants/Profiles.dhall

in

Pipeline.build (ArtifactPipelines.pipeline ArtifactPipelines.ArtifactSpec::{
    profile = Profiles.Type.Lightnet,
    buildOnlyEssentialDockers = True
})
