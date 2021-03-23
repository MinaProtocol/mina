let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let DeployTestnet = ../../Command/DeployTestnet.dhall


let spec = DeployTestnet.DeploySpec::{
  testnetLabel = "nightly",
  workspace = "nightly",
  deployCondition = "build.branch == 'compatible' || build.env('NIGHTLY') == 'true'",
  preDeploy = "terraform destroy -auto-approve",
  extraArgs =  "-var-file=nightly.tfvars",
  deps = [
    { name = "MinaArtifact", key = "mina-docker-image" },
    { name = "ArchiveNodeArtifact", key = "archive-docker-image" }
  ]
}

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [ S.exactly "buildkite/src/Jobs/Test/Nightly" "dhall" ],
      path = "Test",
      name = "Nightly"
    },
    steps = [
      DeployTestnet.step spec
    ]
}
