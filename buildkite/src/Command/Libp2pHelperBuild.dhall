let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let commands : List Cmd.Type =
  [
    Cmd.runInDocker
      Cmd.Docker::{
        image = (../Constants/ContainerImages.dhall).codaToolchain,
        extraEnv = [ "LIBP2P_NIXLESS=1", "GO=/usr/lib/go/bin/go" ]
      }
      "make libp2p_helper",
    Cmd.run "cd src/app/result/bin/ && buildkite-agent artifact upload libp2p_helper"
  ]

in

let cmdDef =
  Command.build
    Command.Config::{
      commands  = commands,
      label = "Libp2p helper commands",
      key = "libp2p-helper",
      target = Size.Small,
      docker = None Docker.Type
    }

in

{ step = cmdDef }
