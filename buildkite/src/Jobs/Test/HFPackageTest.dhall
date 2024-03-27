let MinaArtifact = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build (MinaArtifact.hardforkPipeline MinaArtifact.HardforkPipelineMode/Type.ForTest DebianVersions.DebVersion.Buster)