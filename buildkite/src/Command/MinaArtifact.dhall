let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../Pipeline/Dsl.dhall
let PipelineTag = ../Pipeline/Tag.dhall
let PipelineMode = ../Pipeline/Mode.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ./Base.dhall
let Summon = ./Summon/Type.dhall
let Size = ./Size.dhall
let Libp2p = ./Libp2pHelperBuild.dhall
let DockerImage = ./DockerImage.dhall
let DebianVersions = ../Constants/DebianVersions.dhall
let Profiles = ../Constants/Profiles.dhall

in

let pipeline : DebianVersions.DebVersion -> Profiles.Type ->  PipelineMode.Type -> Pipeline.Config.Type = 
  \(debVersion : DebianVersions.DebVersion) ->
  \(profile: Profiles.Type) ->
  \(mode: PipelineMode.Type) -> 
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen debVersion,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName debVersion}${Profiles.toSuffixUppercase profile}",
          tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ],
          mode = mode
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
              "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}"
            ] "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina for ${DebianVersions.capitalName debVersion} ${Profiles.toSuffixUppercase profile}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          },

        -- daemon berkeley image
        let daemonBerkeleySpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-daemon",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          deb_profile="${Profiles.lowerName profile}",
          step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}-docker-image"
        }

        in

        DockerImage.generateStep daemonBerkeleySpec,

        -- test_executive image
        let testExecutiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-test-executive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="test-executive-${DebianVersions.lowerName debVersion}-docker-image"
        }
        in
        DockerImage.generateStep testExecutiveSpec,

        -- batch_txn_tool image
        let batchTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-batch-txn",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="batch-txn-${DebianVersions.lowerName debVersion}-docker-image"
        }
        in
        DockerImage.generateStep batchTxnSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          deb_profile="${Profiles.lowerName profile}",
          step_key="archive-${DebianVersions.lowerName debVersion}-docker-image"
        }
        in
        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-rosetta",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="rosetta-${DebianVersions.lowerName debVersion}-docker-image"
        }
        in
        DockerImage.generateStep rosettaSpec,

        -- ZkApp test transaction image
        let zkappTestTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-zkapp-test-transaction",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}-docker-image"
        }

        in

        DockerImage.generateStep zkappTestTxnSpec

      ]
    }

in
{
  bullseye  = pipeline DebianVersions.DebVersion.Bullseye Profiles.Type.Standard PipelineMode.Type.PullRequest
  , bullseye-lightnet  = pipeline DebianVersions.DebVersion.Bullseye Profiles.Type.Lightnet PipelineMode.Type.PullRequest
  , buster  = pipeline DebianVersions.DebVersion.Buster Profiles.Type.Standard PipelineMode.Type.PullRequest
  , focal   = pipeline DebianVersions.DebVersion.Focal Profiles.Type.Standard PipelineMode.Type.PullRequest
  }
