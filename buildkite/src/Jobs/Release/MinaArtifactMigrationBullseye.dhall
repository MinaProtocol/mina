let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall
let Profiles = ../../Constants/Profiles.dhall
let Artifacts = ../../Constants/Artifacts.dhall
let Toolchain = ../../Constants/Toolchain.dhall
let ContainerImages = ../../Constants/ContainerImages.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall

in

Pipeline.build 
    (ArtifactPipelines.pipeline 
        [ Artifacts.Type.ArchiveMigration ]
        DebianVersions.DebVersion.Bullseye 
        Profiles.Type.Standard
        (Toolchain.SelectionMode.Custom ContainerImages.minaCaqtiToolchain )
        PipelineMode.Type.PullRequest
    )