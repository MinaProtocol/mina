let Prelude = ../../../External/Prelude.dhall

let Cmd = ../../../Lib/Cmds.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

let Command = ../../../Command/Base.dhall
let OpamInit = ../../../Command/OpamInit.dhall
let Libp2pHelper = ../../../Command/Libp2pHelperBuild.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall

let setupCommands = OpamInit.commands # Libp2pHelper.commands

let buildTestCmd : Text -> Command.Type = \(profile : Text) ->
  Command.build
    Command.Config::{
      commands = setupCommands # [
        Cmd.runInDocker
          Cmd.Docker::{
            image = (../../../Constants/ContainerImages.dhall).codaToolchain,
            extraEnv = [ "DUNE_PROFILE=${profile}", "LIBP2P_NIXLESS=1", "GO=/usr/lib/go/bin/go" ]
          }
          ("source ~/.profile && make build && (dune runtest src/lib --profile=${profile} -j8 || (./scripts/link-coredumps.sh && false))")
      ],
      label = "Run dev unit-tests",
      key = "dev-unit-test",
      target = Size.Large,
      docker = None Docker.Type
    }

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      buildTestCmd "dev",
      buildTestCmd "dev_medium_curves"
    ]
  }

