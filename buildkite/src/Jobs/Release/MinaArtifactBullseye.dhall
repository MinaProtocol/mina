let ArtifactPipelines = ../../Command/MinaArtifact.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

in

Pipeline.build ArtifactPipelines.pipeline 
    DebianVersions.DebVersion.Bullseye 
    Profiles.Type.Standard 
    PipelineMode.Type.PullRequest
    True
