let Prelude = ../../../External/Prelude.dhall

let Decorate = ../../../Lib/Decorate.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let Command = ../../../Command/Base.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

let commonEnvVars = (../../../Constants/ContainerEnvVars.dhall).defaults # ["LIBP2P_NIXLESS=1", "GO=/usr/lib/go/bin/go"]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = Decorate.decorate "bash -c 'source ~/.profile && (dune runtest src/nonconsensus --profile=nonconsensus_medium_curves -j8 || (./scripts/link-coredumps.sh && false))'",
        label = "Run nonconsensus unit-tests",
        key = "unit-nonconsensus",
        target = Size.Large,
        docker = Docker::{
          image = (../../../Constants/ContainerImages.dhall).toolchainBase,
          environment = commonEnvVars # [
            "DUNE_PROFILE=nonconsensus_medium_curves"
          ]
        },
        depends_on = ["build-client-sdk"]
      }
    ]
  }

