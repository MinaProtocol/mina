let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let dependsOn = [
    { name = "MinaArtifact", key = "mina-docker-image" },
    { name = "ArchiveNodeArtifact", key = "archive-docker-image" }
]

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.exactly "buildkite/scripts/connect-to-testnet-on-develop" "sh",
          S.strictlyStart (S.contains "src")
        ],
        path = "Test",
        name = "TestnetIntegrationTest"
      },
    steps = [
        -- Tests that depend on the debian package
        ConnectToTestnet.step dependsOn,
    ]
  }
