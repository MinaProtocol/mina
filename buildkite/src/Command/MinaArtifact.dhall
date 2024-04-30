let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let B = ../External/Buildkite.dhall
let B/If = B.definitions/commandStep/properties/if/Type

let Pipeline = ../Pipeline/Dsl.dhall
let PipelineTag = ../Pipeline/Tag.dhall
let PipelineMode = ../Pipeline/Mode.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Summon = ./Summon/Type.dhall
let Size = ./Size.dhall
let Libp2p = ./Libp2pHelperBuild.dhall
let DockerImage = ./DockerImage.dhall
let DebianVersions = ../Constants/DebianVersions.dhall
let Profiles = ../Constants/Profiles.dhall
let Artifacts = ../Constants/Artifacts.dhall
let Toolchain = ../Constants/Toolchain.dhall

in

let docker_step : Artifacts.Type -> DebianVersions.DebVersion -> Profiles.Type -> DockerImage.ReleaseSpec.Type = 
  \(artifact : Artifacts.Type) ->
  \(debVersion : DebianVersions.DebVersion) ->
  \(profile : Profiles.Type) ->
  let step_dep_name = "upload"
  in
  merge {
        Daemon = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-daemon",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          },

        TestExecutive = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-test-executive",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="test-executive-${DebianVersions.lowerName debVersion}-docker-image"
          },

        BatchTxn = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-batch-txn",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="batch-txn-${DebianVersions.lowerName debVersion}-docker-image"
          },

        Archive = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-archive",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="archive-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          },

        ArchiveMigration = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-archive-migration",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="archive-migration-${DebianVersions.lowerName debVersion}-docker-image"
          },
          
        Rosetta = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-rosetta",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="rosetta-${DebianVersions.lowerName debVersion}-docker-image"
          },

        ZkappTestTransaction = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-zkapp-test-transaction",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          },
        
        FunctionalTestSuite = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOnStep debVersion profile step_dep_name,
            service="mina-test-suite",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="test-suite-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image",
            network="berkeley"
          }
      } artifact
in 


let MinaBuildSpec = {
  Type = {
    prefix: Text,
    artifacts: List Artifacts.Type,
    debVersion : DebianVersions.DebVersion,
    profile: Profiles.Type,
    toolchainSelectMode: Toolchain.SelectionMode,
    mode: PipelineMode.Type
  },
  default = {
    prefix = "MinaArtifact",
    artifacts = Artifacts.AllButTests,
    debVersion = DebianVersions.DebVersion.Bullseye,
    profile = Profiles.Type.Standard,
    toolchainSelectMode = Toolchain.SelectionMode.ByDebian,
    mode = PipelineMode.Type.PullRequest
  }
}


let build_artifacts  = 
  \(spec: MinaBuildSpec.Type) -> 
  Command.build
          Command.Config::{
            commands = Toolchain.select spec.toolchainSelectMode spec.debVersion [
              "DUNE_PROFILE=${Profiles.duneProfile spec.profile}",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName spec.debVersion}"
            ] "./buildkite/scripts/build-release.sh ${Artifacts.toDebianNames spec.artifacts}",
            label = "Build Mina for ${DebianVersions.capitalName spec.debVersion} ${Profiles.toSuffixUppercase spec.profile}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          }

let publish_to_debian_repo = 
   \(spec: MinaBuildSpec.Type) -> 
   Command.build
          Command.Config::{
            commands = Toolchain.select spec.toolchainSelectMode spec.debVersion [
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName spec.debVersion}"
            ] "./buildkite/scripts/publish-deb.sh",
            label = "Publish Mina for ${DebianVersions.capitalName spec.debVersion} ${Profiles.toSuffixUppercase spec.profile}",
            key = "publish-deb-pkg",
            depends_on = DebianVersions.dependsOnStep spec.debVersion spec.profile "build",
            target = Size.Small
          }

let pipeline : MinaBuildSpec.Type -> Pipeline.Config.Type = 
  \(spec: MinaBuildSpec.Type) ->
    let steps = [
        Libp2p.step spec.debVersion,
        (build_artifacts spec),
        (publish_to_debian_repo spec),
      ] # (List/map
            Artifacts.Type
            Command.Type
            (\(artifact : Artifacts.Type) ->  DockerImage.generateStep (docker_step artifact spec.debVersion spec.profile) )
            spec.artifacts)
    in

    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen spec.debVersion,
          path = "Release",
          name = "${spec.prefix}${DebianVersions.capitalName spec.debVersion}${Profiles.toSuffixUppercase spec.profile}",
          tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ],
          mode = spec.mode
        },
      steps = steps
    }

in
{
  pipeline = pipeline
  , MinaBuildSpec = MinaBuildSpec
}
