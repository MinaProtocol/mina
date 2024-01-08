let S = ../../Lib/SelectFiles.dhall
let B = ../../External/Buildkite.dhall
let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

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
      S.exactly "buildkite/scripts/connect-to-testnet" "sh",
      S.exactly "buildkite/src/Jobs/Test/ConnectToTestworld-2-0" "dhall",
      S.exactly "buildkite/src/Command/ConnectToTestnet" "dhall"
    ],
    path = "Test",
    name = "ConnectToTestworld-2-0"
  },
  steps = [
    ConnectToTestnet.step dependsOn "testworld-2-0" "40s" "2m" (B/SoftFail.Boolean False)
  ]
}
