let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let commands : List Cmd.Type =
  [
    Cmd.run "chmod -R 777 src/app/libp2p_helper",
    Cmd.runInDocker
      Cmd.Docker::{
        image = (../Constants/ContainerImages.dhall).codaToolchain,
        extraEnv = [ "GO=/usr/lib/go/bin/go" ]
      }
      "make libp2p_helper",
    Cmd.run "cd src/app/libp2p_helper/result/bin/ && BUILDKITE_ARTIFACT_UPLOAD_DESTINATION=gs://buildkite_k8s/coda/shared/\\\${BUILDKITE_JOB_ID} buildkite-agent artifact upload libp2p_helper"
  ]

in

let cmdConfig =
  Command.build
    Command.Config::{
      commands  = commands,
      label = "Build Libp2p helper",
      key = "libp2p-helper",
      target = Size.Small
    }

in

{ step = cmdConfig }
