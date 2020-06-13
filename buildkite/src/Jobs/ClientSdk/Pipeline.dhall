let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let runD : Cmd.Type -> Cmd.Type =
  \(script: Cmd.Type) ->
    Cmd.inDocker
      Cmd.Docker::{
        image = (../../Constants/ContainerImages.dhall).codaToolchain
      }
      script

let r = Cmd.run in

let opamCommands : List Cmd.Type =
  [
    r "cat scripts/setup-opam.sh > opam_ci_cache.sig",
    r "cat src/opam.export >> opam_ci_cache.sig",
    r "date +%Y-%m >> opam_ci_cache.sig",
    let file =
      "opam-v1-`sha256sum opam_ci_cache.sig | cut -d\" \" -f1`.tar.gz"
    in
    Cmd.cacheThrough
      Cmd.Docker::{
        image = (../../Constants/ContainerImages.dhall).codaToolchain
      }
      file
      Cmd.CompoundCmd::{
        preprocess = r "tar cfz ${file} /home/opam/.opam",
        postprocess = r "tar xfz ${file} -C /home/opam",
        inner = r "make setup-opam"
      }
  ]

let commands =
  opamCommands # [ runD (Cmd.and [
    r "mkdir -p /tmp/artifacts",
    Cmd.seq [
      r "set -o pipefail",
      Cmd.and [
        r "eval `opam config env`",
        r "make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log"
      ]
    ]
  ]) ]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command.build
      Command.Config::{
        commands = commands,
        label = "Build client-sdk",
        key = "build-client-sdk",
        target = Size.Large,
        docker = None Docker.Type
      }
    ]
  }

