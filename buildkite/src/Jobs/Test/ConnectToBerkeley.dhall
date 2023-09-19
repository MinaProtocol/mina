let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let ConnectToTestnet = ../../Command/ConnectToTestnet.dhall

let dependsOn = [
  { name = "MinaArtifactBullseye", key = "daemon-berkeley-bullseye-docker-image" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
      S.strictlyStart (S.contains "src"),
      S.exactly "buildkite/scripts/connect-to-berkeley" "sh",
      S.exactly "buildkite/src/Jobs/Test/ConnectToBerkeley" "dhall",
      S.exactly "buildkite/src/Command/ConnectToTestnet" "dhall"
    ],
    path = "Test",
    name = "ConnectToBerkeley"
  },
  steps = [
    ConnectToTestnet.step dependsOn
  ]
}
