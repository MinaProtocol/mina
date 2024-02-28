let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall
let Profiles = ../../Constants/Profiles.dhall
let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall

in

Pipeline.build 
    (ArtifactPipelines.pipeline 
        [ Artifact.Daemon , Artifact.Archive , Artifact.BatchTxn , Artifact.TestExecutive , Artifact.Rosetta , Artifact.ZkappTestTransaction ]
        DebianVersions.DebVersion.Focal 
        Profiles.Type.Standard 
        PipelineMode.Type.PullRequest
    )