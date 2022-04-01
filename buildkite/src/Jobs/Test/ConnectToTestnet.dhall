let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let ConnectToTestnet = ../../Command/ConnectToTestnet.dhall

let dependsOnStretch = [
  { name = "MinaArtifactBullseye", key = "daemon-mainnet-bullseye-docker-image" }
]

in Pipeline.build Pipeline.Config::{
  spec =
    JobSpec::{
    dirtyWhen = [
      S.strictlyStart (S.contains "src"),
      S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh"
    ],
    path = "Test",
    name = "ConnectToTestnet"
  },
  steps = [
    ConnectToTestnet.step dependsOnStretch
  ]
}
