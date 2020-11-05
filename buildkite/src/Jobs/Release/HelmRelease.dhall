let Prelude = ../../External/Prelude.dhall
let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let jobDocker = Cmd.Docker::{image = (../../Constants/ContainerImages.dhall).codaToolchain}

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [
        S.contains "helm",
        S.strictly (S.contains "Chart.yaml"),
        S.strictlyStart (S.contains "buildkite/src/Jobs/Release/HelmRelease"),
        S.exactly "buildkite/scripts/helm-ci" "sh"
      ],
      path = "Release",
      name = "HelmRelease"
    },
    steps = [
      Command.build
        Command.Config::{
          commands = [ Cmd.run "AUTO_DEPLOY=true HELM_RELEASE=true buildkite/scripts/helm-ci.sh" ]
          , label = "Helm chart release"
          , key = "release-helm-chart"
          , target = Size.Medium
          , docker = None Docker.Type
          , soft_fail = Some (B/SoftFail.Boolean True)
          , artifact_paths = [ S.contains "updates/*" ]
          , depends_on = [ { name = "HelmChart", key = "lint-helm-chart" } ]
        }
    ]
  }
