let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ../Command/Base.dhall
let OpamInit = ../Command/OpamInit.dhall
let Summon = ../Command/Summon/Type.dhall
let Size = ../Command/Size.dhall
let Libp2p = ../Command/Libp2pHelperBuild.dhall

in
Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = OpamInit.dirtyWhen # [
          S.strictlyStart (S.contains "src"),
          S.strictly (S.contains "Makefile"),
          S.strictlyStart (S.contains "buildkite/src/Jobs/Artifact"),
          S.exactly "buildkite/scripts/build-artifact" "sh",
          S.strictlyStart (S.contains "scripts")
        ],
        name = "Artifact"
      },
    steps = [
      Libp2p.step,
      Command.build
        Command.Config::{
          commands = OpamInit.andThenRunInDocker [
            "DUNE_PROFILE=testnet_postake_medium_curves",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY"
          ] "./buildkite/scripts/build-artifact.sh" # [ "buildkite-agent artifact upload ./DOCKER_DEPLOY_ENV" ],
          label = "Build artifacts",
          key = "artifacts-build",
          target = Size.Large
        }
    ]
  }
