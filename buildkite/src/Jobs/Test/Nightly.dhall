let S = ../../Lib/SelectFiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall

let DeployTestnet = ../../Command/DeployTestnet.dhall

let dependsOn = [
    { name = "MinaArtifact", key = "mina-docker-image" },
    { name = "ArchiveNodeArtifact", key = "archive-docker-image" }
]

let spec = DeployTestnet.DeploySpec::{
  workspace = "nightly",
  deployCondition = "build.branch == 'compatible' && build.env('NIGHTLY') == 'true'",
  preDeploy = "terraform destroy -auto-approve",
  deps = [
    { name = "MinaArtifact", key = "mina-docker-image" },
    { name = "ArchiveNodeArtifact", key = "archive-docker-image" }
  ]
}

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [ S.strictlyStart (S.contains "src") ],
      path = "Test",
      name = "Nightly"
    },
    steps = [
      DeployTestnet.step spec
    ]
}
