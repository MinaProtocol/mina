let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Summon = ../../Command/Summon/Type.dhall
let Size = ../../Command/Size.dhall
let Libp2p = ../../Command/Libp2pHelperBuild.dhall
let ConnectToTestnet = ../../Command/ConnectToTestnet.dhall
let DockerImage = ../../Command/DockerImage.dhall

let dependsOnGitEnv = [ { name = "GitEnvUpload", key = "upload-git-env" } ]

let DebVersion = < Buster | Stretch >

let capitalName = \(debVersion : DebVersion) ->
  merge { Buster = "Buster", Stretch = "Stretch" } debVersion
 
let lowerName = \(debVersion : DebVersion) ->
  merge { Buster = "buster", Stretch = "stretch" } debVersion

let toolchainRunner = \(debVersion : DebVersion) ->
  merge { Buster = RunInToolchain.runInToolchainBuster, Stretch = RunInToolchain.runInToolchainStretch } debVersion

let dependsOn = \(debVersion : DebVersion) ->
  merge {
    Buster = [ dependsOnGitEnv # { name = "MinaArtifactBuster", key = "build-deb-pkg" }],
    Stretch = [ dependsOnGitEnv # { name = "MinaArtifactStretch", key = "build-deb-pkg" }]
  } debVersion

let pipeline = \(debVersion : DebVersion) -> 
  Pipeline.build
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = [
            S.strictlyStart (S.contains "src"),
            S.strictlyStart (S.contains "automation"),
            S.strictly (S.contains "Makefile"),
            S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact"),
            S.strictlyStart (S.contains "buildkite/src/Command/MinaArtifact"),
            S.exactly "buildkite/scripts/build-artifact" "sh",
            S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh",
            S.strictlyStart (S.contains "dockerfiles"),
            S.strictlyStart (S.contains "scripts")
          ],
          path = "Release",
          name = "MinaArtifact${capitalName(debVersion)}"
        },
      steps = [
        Libp2p.step,
        Command.build
          Command.Config::{
            commands = toolchainRunner(debVersion) [
              "DUNE_PROFILE=devnet",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${lowerName(debVersion)}",
              -- add zexe standardization preprocessing step (see: https://github.com/MinaProtocol/mina/pull/5777)
              "PREPROCESSOR=./scripts/zexe-standardize.sh"
            ] "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina daemon package for Debian ${capitalName(debVersion)}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [ Command.Retry::{ exit_status = +2, limit = Some 2 } ] -- libp2p error
          },

        -- daemon devnet image
        let daemonDevnetSpec = DockerImage.ReleaseSpec::{
          deps=dependsOn(debVersion),
          service="mina-daemon",
          network="devnet",
          deb_codename="${lowerName(debVersion)}",
          step_key="daemon-devnet-${lowerName(debVersion)}-docker-image"
        }

        in

        DockerImage.generateStep daemonDevnetSpec,

        -- daemon mainnet image
        let daemonMainnetSpec = DockerImage.ReleaseSpec::{
          deps=dependsOn(debVersion),
          service="mina-daemon",
          network="mainnet",
          deb_codename="${lowerName(debVersion)}",
          step_key="daemon-mainnet-${lowerName(debVersion)}-docker-image"
        }

        in

        DockerImage.generateStep daemonMainnetSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=dependsOn(debVersion),
          service="mina-archive",
          deb_codename="${lowerName(debVersion)}",
          step_key="archive-${lowerName(debVersion)}-docker-image"
        }

        in

        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          deps=dependsOnGitEnv,
          service="mina-rosetta",
          extra_args="--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --build-arg MINA_REPO=\\\${BUILDKITE_PULL_REQUEST_REPO}",
          deb_codename="${lowerName(debVersion)}",
          step_key="rosetta-mainnet-${lowerName(debVersion)}-docker-image"
        }

        in

        DockerImage.generateStep rosettaSpec

      ]
    }

in

let buster = pipeline Buster
let stretch = pipeline Stretch