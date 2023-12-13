let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall

let spec = DockerImage.ReleaseSpec::{
    service="mina-receipt-chain-hash-fix",
    step_key="receipt-chain-hash-fix-docker-image",
    network="berkeley",
    deps = [ { name = "MinaArtifactBullseye", key = "daemon-berkeley-bullseye-docker-image" } ]
}

in	

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/ReceiptChainHashFixArtifact"),
          S.strictlyStart (S.contains "src/app/receipt_chain_hash_to_b58"),
          S.strictlyStart (S.contains "src/app/last_vrf_output_to_b64")
        ],
        path = "Release",
        name = "ReceiptChainHashFixArtifact"
      },
    steps = [
      DockerImage.generateStep spec
    ]
  }




