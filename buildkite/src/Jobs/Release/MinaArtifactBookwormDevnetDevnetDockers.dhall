let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let ArtifactSpecs = ../../Command/MinaArtifactSpecs.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      (ArtifactPipelines.dockersPipeline ArtifactSpecs.bookwormDevnetDevnet)
