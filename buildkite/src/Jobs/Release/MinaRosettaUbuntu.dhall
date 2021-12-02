let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall
let DockerLogin = ../../Command/DockerLogin/Type.dhall


in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "dockerfiles/stages/1-"),
          S.strictlyStart (S.contains "dockerfiles/stages/2-"),
          S.strictlyStart (S.contains "dockerfiles/stages/3-"),
          S.strictlyStart (S.contains "dockerfiles/stages/4-"),
          S.strictlyStart (S.contains "dockerfiles/stages/5-"),
          S.strictlyStart (S.contains "src/app/rosetta")
        ],
        path = "Release",
        name = "MinaRosettaUbuntu"
      },
    steps = [

      -- mina-rosetta-ubuntu Ubuntu Rosetta image
      let rosettaUbuntuSpec = DockerImage.ReleaseSpec::{
        service="mina-rosetta-ubuntu",
        deb_codename="stretch",
        extra_args="--no-cache",
        step_key="mina-rosetta-ubuntu-docker-image"
      }

      in

      DockerImage.generateStep rosettaUbuntuSpec

    ]
  }
