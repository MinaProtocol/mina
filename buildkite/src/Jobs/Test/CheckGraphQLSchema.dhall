let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let CheckGraphQLSchema = ../../Command/CheckGraphQLSchema.dhall

let dependsOn = [
    { name = "MinaArtifactBullseye", key = "builder-bullseye" }
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
    name = "CheckGraphQLSchema"
  },
  steps = [
    CheckGraphQLSchema.step dependsOn
  ]
}
