let ArtifactPipelines = ../../Command/MinaArtifact.dhall
let BuildFlags = ../../Constants/BuildFlags.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

in

Pipeline.build (ArtifactPipelines.pipeline ArtifactPipelines.ArtifactSpec::{
    buildFlags = BuildFlags.Type.Instrumented,
    buildOnlyEssentialDockers = True
})