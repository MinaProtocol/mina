let ArtifactPipelines = ../../Command/MinaArtifact.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

in

Pipeline.build (ArtifactPipelines.pipeline ArtifactPipelines.ArtifactSpec::{
    extraEnv =  ["DUNE_INSTRUMENT_WITH=bisect_ppx"],
    buildOnlyEssentialDockers = True,
    extraSuffix =  "WithInstrumentation"
})