let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Coda = ../../Command/Coda.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = [ Coda.fixPermissionsCommand ] # OpamInit.commands # [
          Cmd.runInDocker
            Cmd.Docker::{
              image = (../../Constants/ContainerImages.dhall).codaToolchain
            }
            ("opam install dune ppx_custom_printf js_of_ocaml-compiler js_of_ocaml-ppx && " ++
              "mkdir -p /tmp/artifacts && (" ++
              "set -o pipefail ; " ++
              "./buildkite/scripts/opam-env.sh && " ++
              "make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log" ++
            ")")
        ],
        label = "Build client-sdk",
        key = "build-client-sdk",
        target = Size.Large,
        docker = None Docker.Type
      }
    ]
  }

