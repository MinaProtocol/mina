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

in

let pipeline : DebianVersions.DebVersion -> Pipeline.Config.Type = \(debVersion : DebianVersions.DebVersion) ->
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen debVersion,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName debVersion}"
        },
      steps = [

        -- builder image
        let minaBuilderSpec = DockerImage.ReleaseSpec::{
          service="mina-builder",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="builder-${DebianVersions.lowerName debVersion}",
          version="${DebianVersions.lowerName debVersion}-\\\${BUILDKITE_COMMIT}"
        }

        in

        DockerImage.generateStep minaBuilderSpec,

        -- daemon devnet image
        let daemonDevnetSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="devnet",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-devnet-${DebianVersions.lowerName debVersion}"
        }

        in

        DockerImage.generateStep daemonDevnetSpec,

        -- daemon mainnet image
        let daemonMainnetSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="mainnet",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-mainnet-${DebianVersions.lowerName debVersion}"
        }

        in

        DockerImage.generateStep daemonMainnetSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="archive-${DebianVersions.lowerName debVersion}"
        }

        in

        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          service="mina-rosetta",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="rosetta-${DebianVersions.lowerName debVersion}"
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
  , focal   = pipeline DebianVersions.DebVersion.Focal
  , bionic  = pipeline DebianVersions.DebVersion.Bionic
}
