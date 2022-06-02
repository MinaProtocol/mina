let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ./Base.dhall
let Summon = ./Summon/Type.dhall
let Size = ./Size.dhall
let Libp2p = ./Libp2pHelperBuild.dhall
let DockerImage = ./DockerImage.dhall
let DebianVersions = ../Constants/DebianVersions.dhall
let dirtyWhen = [
  S.strictlyStart (S.contains "src"),
  S.strictlyStart (S.contains "automation"),
  S.strictly (S.contains "Makefile"),
  S.strictlyStart (S.contains "buildkite/src/Command/MinaArtifact"),
  S.exactly "buildkite/scripts/build-artifact" "sh",
  S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh",
  S.strictlyStart (S.contains "buildkite/src/Jobs/Test"),
  S.strictlyStart (S.contains "buildkite/src/Command"),
  S.strictlyStart (S.contains "dockerfiles"),
  S.strictlyStart (S.contains "scripts")
]


in

let pipeline : DebianVersions.DebVersion -> Pipeline.Config.Type = \(debVersion : DebianVersions.DebVersion) ->
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = dirtyWhen,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName debVersion}"
        },
      steps = [
        Libp2p.step debVersion,
        Command.build
          Command.Config::{
            commands = DebianVersions.toolchainRunner debVersion [
              "DUNE_PROFILE=devnet",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}",
              -- add zexe standardization preprocessing step (see: https://github.com/MinaProtocol/mina/pull/5777)
              "PREPROCESSOR=./scripts/zexe-standardize.sh"
            ] "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina for ${DebianVersions.capitalName debVersion}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          },

        -- daemon devnet image
        let daemonDevnetSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="devnet",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-devnet-${DebianVersions.lowerName debVersion}-docker-image"
        }

        in

        DockerImage.generateStep daemonDevnetSpec,

        -- daemon mainnet image
        let daemonMainnetSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="mainnet",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-mainnet-${DebianVersions.lowerName debVersion}-docker-image"
        }

        in

        DockerImage.generateStep daemonMainnetSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="archive-${DebianVersions.lowerName debVersion}-docker-image"
        }

        in

        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          service="mina-rosetta",
          extra_args=["--build-arg", "MINA_BRANCH=\\\${BUILDKITE_BRANCH}", "--no-cache"],
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="rosetta-${DebianVersions.lowerName debVersion}-docker-image"
        }

        in

        DockerImage.generateStep rosettaSpec

      ]
    }

in
{
  bullseye  = pipeline DebianVersions.DebVersion.Bullseye
  , buster  = pipeline DebianVersions.DebVersion.Buster
  , stretch = pipeline DebianVersions.DebVersion.Stretch
  , bionic = pipeline DebianVersions.DebVersion.Bionic
  , focal   = pipeline DebianVersions.DebVersion.Focal
  , dirtyWhen = dirtyWhen
}
