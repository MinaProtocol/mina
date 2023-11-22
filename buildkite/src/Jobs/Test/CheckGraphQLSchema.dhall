let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let CheckGraphQLSchema = ../../Command/CheckGraphQLSchema.dhall

let dependsOn = [
    { name = "MinaArtifactBullseye", key = "build-deb-pkg" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
      S.strictlyStart (S.contains "src"),
      S.exactly "buildkite/scripts/check-graphql-schema" "sh",
      S.strictly (S.contains "Makefile")
    ],
    path = "Test",
    name = "CheckGraphQLSchema", 
    tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
  },
  steps = [
    CheckGraphQLSchema.step dependsOn
  ]
}
