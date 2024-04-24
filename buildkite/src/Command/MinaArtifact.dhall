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
let Profiles = ../Constants/Profiles.dhall

in

let build_daemon_docker_step : Profiles.Type -> DebianVersions.DebVersion -> DockerImage.ReleaseSpec.Type = 
  \(profile: Profiles.Type) ->
  \(debVersion : DebianVersions.DebVersion) ->

    merge {
      Devnet = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="devnet",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-devnet-${DebianVersions.lowerName debVersion}-profile-${Profiles.lowerName profile}-docker-image"
        },
      Mainnet = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="mainnet",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-mainnet-${DebianVersions.lowerName debVersion}-profile-${Profiles.lowerName profile}-docker-image"
        }
    } profile

in

let pipeline : DebianVersions.DebVersion -> Profiles.Type -> Pipeline.Config.Type = 
  \(debVersion : DebianVersions.DebVersion) ->
  \(profile: Profiles.Type) ->

    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen debVersion,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName debVersion}${Profiles.capitalName profile}"
        },
      steps = [
        Libp2p.step debVersion,
        Command.build
          Command.Config::{
            commands = DebianVersions.toolchainRunner debVersion [
              "DUNE_PROFILE=${Profiles.duneProfile profile}",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}",
              -- add zexe standardization preprocessing step (see: https://github.com/MinaProtocol/mina/pull/5777)
              "PREPROCESSOR=./scripts/zexe-standardize.sh"
            ] "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina for ${DebianVersions.capitalName debVersion} with profile ${Profiles.capitalName profile}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          },


        DockerImage.generateStep (build_daemon_docker_step profile debVersion),

        -- test_executive image
        let testExecutiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-test-executive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="test-executive-${DebianVersions.lowerName debVersion}-profile-${Profiles.lowerName profile}-docker-image"
        }
        in
        DockerImage.generateStep testExecutiveSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="archive-${DebianVersions.lowerName debVersion}-profile-${Profiles.lowerName profile}-docker-image"
        }
        in
        DockerImage.generateStep archiveSpec,

        -- archive maintenance image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-archive-maintenance",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="archive-maintenance-${DebianVersions.lowerName debVersion}-profile-${Profiles.lowerName profile}-docker-image"
        }
        in
        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          service="mina-rosetta",
          extra_args="--build-arg MINA_BRANCH=\\\${BUILDKITE_BRANCH} --no-cache",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="rosetta-${DebianVersions.lowerName debVersion}-profile-${Profiles.lowerName profile}-docker-image"
        }
        in
        DockerImage.generateStep rosettaSpec

      ]
    }

in
{
  bullseyeDevnet  = pipeline DebianVersions.DebVersion.Bullseye Profiles.Type.Devnet
  , busterDevnet  = pipeline DebianVersions.DebVersion.Buster Profiles.Type.Devnet
  , stretchDevnet = pipeline DebianVersions.DebVersion.Stretch Profiles.Type.Devnet
  , focalDevnet   = pipeline DebianVersions.DebVersion.Focal Profiles.Type.Devnet
  , bionicDevnet  = pipeline DebianVersions.DebVersion.Bionic Profiles.Type.Devnet
  , bullseyeMainnet  = pipeline DebianVersions.DebVersion.Bullseye Profiles.Type.Mainnet
  , busterMainnet  = pipeline DebianVersions.DebVersion.Buster Profiles.Type.Mainnet
  , stretchMainnet = pipeline DebianVersions.DebVersion.Stretch Profiles.Type.Mainnet
  , focalMainnet   = pipeline DebianVersions.DebVersion.Focal Profiles.Type.Mainnet
  , bionicMainnet  = pipeline DebianVersions.DebVersion.Bionic Profiles.Type.Mainnet

}
