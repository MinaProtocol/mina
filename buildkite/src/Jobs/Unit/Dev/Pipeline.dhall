let Prelude = ../../../External/Prelude.dhall

let Decorate = ../../../Lib/Decorate.dhall

let Pipeline = ../../../Pipeline/Dsl.dhall
let Command = ../../../Command/Base.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall
let JobSpec = ../../../Pipeline/JobSpec.dhall

let commands =
  [
    "bash -c 'source ~/.profile && make build && (dune runtest src/lib --profile=dev -j8 || (./scripts/link-coredumps.sh && false))'",
    "./scripts/skip_if_only_frontend_or_rfcs.sh bash -c 'source ~/.profile && export GO=/usr/lib/go/bin/go && make build && (dune runtest src/lib --profile=dev_medium_curves -j8 || (./scripts/link-coredumps.sh && false))'"
  ]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = Decorate.decorateAll commands,
        label = "Unit Tests: dev, dev_medium_curves",
        key = "unit",
        target = Size.Small,
        docker = Docker::{
          image = (../../../Constants/ContainerImages.dhall).toolchainBase,
          environment = (../../../Constants/ContainerEnvVars.dhall).defaults # [
            "LIBP2P_NIXLESS=1",
            "GO=/usr/lib/go/bin/go"
          ]
        }
      }
    ]
  }

