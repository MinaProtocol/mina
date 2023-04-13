let ArtifactPipelines = ../../Command/MinaArtifactInstrumentation.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

in

Pipeline.build ArtifactPipelines.bullseye
