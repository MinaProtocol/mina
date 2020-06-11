let Prelude = ../../../External/Prelude.dhall

let Decorate = ../../../Lib/Decorate.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let Command = ../../../Command/Base.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

let commonEnvVars = (../../../Constants/ContainerEnvVars.dhall).defaults # ["LIBP2P_NIXLESS=1", "GO=/usr/lib/go/bin/go"]
let commonStepDeps = ["build-client-sdk"]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = Decorate.decorate "bash -c 'source ~/.profile && make build && (dune runtest src/lib --profile=dev -j8 || (./scripts/link-coredumps.sh && false))'",
        label = "Run dev unit-tests",
        key = "unit-dev",
        target = Size.Large,
        docker = Docker::{
          image = (../../../Constants/ContainerImages.dhall).toolchainBase,
          environment = commonEnvVars # [
            "DUNE_PROFILE=dev"
          ]
        },
        depends_on = commonStepDeps
      },
      Command.Config::{
        commands = Decorate.decorate "bash -c 'source ~/.profile && export GO=/usr/lib/go/bin/go && make build && (dune runtest src/lib --profile=dev_medium_curves -j8 || (./scripts/link-coredumps.sh && false))'",
        label = "Run dev_medium_curves unit tests",
        key = "unit-dev-medium-curves",
        target = Size.Large,
        docker = Docker::{
          image = (../../../Constants/ContainerImages.dhall).toolchainBase,
          environment = commonEnvVars # [
            "DUNE_PROFILE=dev_medium_curves"
          ]
        },
        depends_on = commonStepDeps
      }
    ]
  }
