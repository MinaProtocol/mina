let Prelude = ../../External/Prelude.dhall

let Decorate = ../../Lib/Decorate.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let Command/Coda = ../../Command/Coda.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let opamCommands =
  [
    "cat scripts/setup-opam.sh > opam_ci_cache.sig",
    "cat src/opam.export >> opam_ci_cache.sig",
    "date +%Y-%m >> opam_ci_cache.sig",
    "make setup-opam"
-- TODO: Artifact caching
  ]

let commands =
  opamCommands # [
    "mkdir -p /tmp/artifacts",
    "bash -c 'set -o pipefail; eval `opam config env` && make client_sdk 2>&1 | tee /tmp/artifacts/buildclientsdk.log'"
  ]

in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
    Command/Coda.build
      Command/Coda.Config::{
        commands = Decorate.decorateAll commands,
        label = "Build client-sdk",
        key = "build-client-sdk"
      }
    ]
  }

