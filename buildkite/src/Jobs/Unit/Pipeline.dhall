let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Libp2pHelper = ../../Command/Libp2pHelperBuild.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let setupCommands = OpamInit.commands # Libp2pHelper.commands

let buildTestCmd : Text -> Text -> Command.Type = \(profile : Text) -> \(path : Text) ->
  Command.build
    Command.Config::{
      commands = setupCommands # [
        Cmd.runInDocker
          Cmd.Docker::{
            image = (../../Constants/ContainerImages.dhall).codaToolchain,
            extraEnv = [ "DUNE_PROFILE=${profile}", "LIBP2P_NIXLESS=1", "GO=/usr/lib/go/bin/go" ]
          }
          ("source ~/.profile && make build && (dune runtest ${path} --profile=${profile} -j8 || (./scripts/link-coredumps.sh && false))")
      ],
      label = "Run ${profile} unit-tests",
      key = "unit-test-${profile}",
      target = Size.Large,
      docker = None Docker.Type
    }

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      buildTestCmd "dev" "src/lib",
      buildTestCmd "dev_medium_curves" "src/lib",
      buildTestCmd "nonconsensus_medium_curves" "src/nonconsensus"
    ]
  }

