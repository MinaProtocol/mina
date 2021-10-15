let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let CheckSnarkyJSBindings = ../../Command/CheckSnarkyJSBindings.dhall

let dependsOn = [
    { name = "MinaArtifactStretch", key = "build-deb-pkg" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
      S.strictlyStart (S.contains "src"),
      S.exactly "buildkite/scripts/check-snarkyjs-bindings" "sh",
      S.strictly (S.contains "Makefile")
    ],
    path = "Test",
    name = "CheckSnarkyJSBindings"
  },
  steps = [
    CheckSnarkyJSBindings.step dependsOn
  ]
}
