let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let OpamInit = ../../Command/OpamInit.dhall
let Summon = ../../Command/Summon/Type.dhall
let Size = ../../Command/Size.dhall
let Libp2p = ../../Command/Libp2pHelperBuild.dhall
let DockerArtifact = ../../Command/DockerArtifact.dhall

let dependsOn = [ { name = "CodaArtifact", key = "artifacts-build" } ]

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = OpamInit.dirtyWhen # [
          S.strictlyStart (S.contains "src"),
          S.strictly (S.contains "Makefile"),
          S.strictlyStart (S.contains "buildkite/src/Jobs/CodaArtifact"),
          S.exactly "buildkite/scripts/build-artifact" "sh",
          S.strictlyStart (S.contains "scripts")
        ],
        path = "Release",
        name = "CodaArtifact"
      },
    steps = [
      Libp2p.step,
      Command.build
        Command.Config::{
          commands = OpamInit.andThenRunInDocker [
            "DUNE_PROFILE=testnet_postake_medium_curves",
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY",
            -- add zexe standardization preprocessing step (see: https://github.com/CodaProtocol/coda/pull/5777)
            "PREPROCESSOR=./scripts/zexe-standardize.sh"
          ] "./buildkite/scripts/build-artifact.sh" # [ Cmd.run "buildkite-agent artifact upload ./DOCKER_DEPLOY_ENV" ],
          label = "Build artifacts",
          key = "artifacts-build",
          target = Size.XLarge,
          artifact_paths = [ S.contains "_build/*" ]
        },

      -- daemon image
      let daemonSpec = DockerArtifact.ReleaseSpec::{
        deps=dependsOn,
        service="coda-daemon"
      }

      in

      DockerArtifact.generateStep daemonSpec,

      -- puppeteered image
      let puppeteeredSpec = DockerArtifact.ReleaseSpec::{
        deps=dependsOn,
        service="\\\${CODA_SERVICE}-puppeteered",
        extra_args="--build-arg coda_deb_version=\\\${CODA_DEB_VERSION} --build-arg CODA_VERSION=\\\${CODA_VERSION} --build-arg CODA_BRANCH=\\\${CODA_GIT_BRANCH} --build-arg deb_repo=\\\${CODA_DEB_REPO}"
      }

      in

      DockerArtifact.generateStep puppeteeredSpec,

          -- rosetta image
      let rosettaSpec = DockerArtifact.ReleaseSpec::{
        deps=dependsOn,
        service="coda-rosetta",
        extra_args="--build-arg MINA_BRANCH=\\\${CODA_GIT_BRANCH} --cache-from gcr.io/o1labs-192920/mina-rosetta-opam-deps:develop"
      }

      in

      DockerArtifact.generateStep rosettaSpec,

      -- rosetta image w/ DUNE_PROFILE=dev
      let rosettaDuneSpec = DockerArtifact.ReleaseSpec::{
        deps=dependsOn,
        service="coda-rosetta",
        version="dev-\\\${CODA_VERSION}",
        extra_args="--build-arg DUNE_PROFILE=dev --build-arg MINA_BRANCH=\\\${CODA_GIT_BRANCH} --cache-from gcr.io/o1labs-192920/mina-rosetta-opam-deps:develop"
      }

      in

      DockerArtifact.generateStep rosettaDuneSpec
    ]
  }
