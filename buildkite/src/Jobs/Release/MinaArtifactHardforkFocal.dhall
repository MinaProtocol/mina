let MinaArtifact = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build (MinaArtifact.hardforkPipeline DebianVersions.DebVersion.Focal)
