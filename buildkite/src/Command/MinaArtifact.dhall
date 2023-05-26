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

        -- daemon berkeley image
        let daemonBerkeleySpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-daemon",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}"
        }

        in

        DockerImage.generateStep daemonBerkeleySpec,

        -- test_executive image
        let testExecutiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-test-executive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="test-executive-${DebianVersions.lowerName debVersion}"
        }
        in
        DockerImage.generateStep testExecutiveSpec,

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

        DockerImage.generateStep rosettaSpec,

        -- ZkApp test transaction image
        let zkappTestTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-zkapp-test-transaction",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}"
        }

        in

        DockerImage.generateStep zkappTestTxnSpec

      ]
    }

in
{
  bullseye  = pipeline DebianVersions.DebVersion.Bullseye
  , buster  = pipeline DebianVersions.DebVersion.Buster
  , focal   = pipeline DebianVersions.DebVersion.Focal
}
