let ArtifactPipelines = ../../Command/MinaArtifact.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let DebianVersions = ../../Constants/DebianVersions.dhall

in

Pipeline.build (ArtifactPipelines.pipeline ArtifactPipelines.ArtifactSpec::{
    debVersion = DebianVersions.DebVersion.Focal
})