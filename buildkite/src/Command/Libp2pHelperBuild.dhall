let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let commands = \(debVersion : DebianVersions.DebVersion) ->
  [
    Cmd.run "chmod -R 777 src/app/libp2p_helper",
    Cmd.run "chmod -R 777 src/libp2p_ipc",
    Cmd.runInDocker
      Cmd.Docker::{
        image = DebianVersions.toolchainImage debVersion,
        extraEnv = [ "GO=/usr/lib/go/bin/go" ]
      }
      "make libp2p_helper",
    Cmd.run "cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper"
  ]

in

let cmdConfig = \(debVersion : DebianVersions.DebVersion) ->
  Command.build
    Command.Config::{
      commands  = commands debVersion,
      label = "Build Libp2p helper for ${DebianVersions.capitalName debVersion}",
      key = "libp2p-helper",
      target = Size.Small
    }

in

{ step = cmdConfig }
