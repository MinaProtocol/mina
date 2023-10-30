let ArtifactPipelines = ../../Command/MinaArtifactInstrumentation.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let DockerImage = ./DockerImage.dhall
let DebianVersions = ../Constants/DebianVersions.dhall

in

Pipeline.build ArtifactPipelines.pipeline 
    DebianVersions.DebVersion.Bullseye 
    Profiles.Type.Standard 
    PipelineMode.Type.PullRequest
    ["DUNE_INSTRUMENT_WITH=bisect_ppx"]
    False
