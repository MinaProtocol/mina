let Prelude = ../External/Prelude.dhall
let B = ../External/Buildkite.dhall
let B/If = B.definitions/commandStep/properties/if/Type

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
  
let ArtifactSpec = {
  Type = {
    debVersion : DebianVersions.DebVersion,
    profile: Profiles.Type,
    mode: PipelineMode.Type,
    extraEnv: List Text,
    buildOnlyEssentialDockers: Bool,
    extraSuffix: Text
  },
  default = {
    debVersion = DebianVersions.DebVersion.Bullseye,
    profile = Profiles.Type.Standard,
    mode = PipelineMode.Type.PullRequest,
    extraEnv = ([]: List Text),
    buildOnlyEssentialDockers = False,
    extraSuffix = ""
  }
}

let pipeline =  
  \(spec : ArtifactSpec.Type) ->
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen spec.debVersion,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName spec.debVersion}${Profiles.toSuffixUppercase spec.profile}${spec.extraSuffix}",
          tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ],
          mode = spec.mode
        },
      steps = [
        Libp2p.step spec.debVersion,
        Command.build
          Command.Config::{
            commands = DebianVersions.toolchainRunner spec.debVersion ([
              "DUNE_PROFILE=${Profiles.duneProfile spec.profile}",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName spec.debVersion}"
            ] # spec.extraEnv)
            "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina for ${DebianVersions.capitalName spec.debVersion} ${Profiles.toSuffixUppercase spec.profile}",
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
          deps=DebianVersions.dependsOn spec.debVersion spec.profile,
          service="mina-daemon",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName spec.debVersion}",
          deb_profile="${Profiles.lowerName spec.profile}",
          step_key="daemon-berkeley-${DebianVersions.lowerName spec.debVersion}${Profiles.toLabelSegment spec.profile}-docker-image"
        }

        in

        DockerImage.generateStep daemonBerkeleySpec,

        -- test_executive image
        let testExecutiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn spec.debVersion spec.profile,
          service="mina-test-executive",
          deb_codename="${DebianVersions.lowerName spec.debVersion}",
          step_key="test-executive-${DebianVersions.lowerName spec.debVersion}-docker-image",
          `if`=Some "'${Profiles.lowerName spec.profile}' == 'standard' && '${Prelude.Bool.show spec.buildOnlyEssentialDockers}' == 'False'"
        }
        in
        DockerImage.generateStep testExecutiveSpec,

        -- batch_txn_tool image
        let batchTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn spec.debVersion spec.profile,
          service="mina-batch-txn",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName spec.debVersion}",
          step_key="batch-txn-${DebianVersions.lowerName spec.debVersion}-docker-image",
          `if`=Some "'${Profiles.lowerName spec.profile}' == 'standard' && '${Prelude.Bool.show spec.buildOnlyEssentialDockers}' == 'False'"
        }
        in
        DockerImage.generateStep batchTxnSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn spec.debVersion spec.profile,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName spec.debVersion}",
          deb_profile="${Profiles.lowerName spec.profile}",
          step_key="archive-${DebianVersions.lowerName spec.debVersion}${Profiles.toLabelSegment spec.profile}-docker-image"
        }
        in
        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn spec.debVersion spec.profile,
          service="mina-rosetta",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName spec.debVersion}",
          step_key="rosetta-${DebianVersions.lowerName spec.debVersion}-docker-image",
          `if`=Some "'${Profiles.lowerName spec.profile}' == 'standard' && '${Prelude.Bool.show spec.buildOnlyEssentialDockers}' == 'False'"
        }
        in
        DockerImage.generateStep rosettaSpec,

        -- ZkApp test transaction image
        let zkappTestTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn spec.debVersion spec.profile,
          service="mina-zkapp-test-transaction",
          deb_codename="${DebianVersions.lowerName spec.debVersion}",
          step_key="zkapp-test-transaction-${DebianVersions.lowerName spec.debVersion}${Profiles.toLabelSegment spec.profile}-docker-image",
          `if`=Some "'${Profiles.lowerName spec.profile}' == 'standard' && '${Prelude.Bool.show spec.buildOnlyEssentialDockers}' == 'False'"
        }

        in

        DockerImage.generateStep zkappTestTxnSpec

      ]
    }

in 
{ pipeline = pipeline, ArtifactSpec = ArtifactSpec }