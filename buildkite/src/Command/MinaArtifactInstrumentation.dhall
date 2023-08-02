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
          name = "MinaArtifact${DebianVersions.capitalName debVersion}WithInstrumentation"
        },
      steps = [
        Libp2p.step debVersion,
        Command.build
          Command.Config::{
            commands = DebianVersions.toolchainRunner debVersion [
              "DUNE_INSTRUMENT_WITH=bisect_ppx",
              "DUNE_PROFILE=devnet",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}",
              -- add zexe standardization preprocessing step (see: https://github.com/MinaProtocol/mina/pull/5777)
              "PREPROCESSOR=./scripts/zexe-standardize.sh"
            ] "./buildkite/scripts/build-artifact.sh",
            label = "Build Mina for ${DebianVersions.capitalName debVersion} with instrumentation",
            key = "build-deb-pkg-instr",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          },

        -- daemon berkeley image
        let daemonBerkeleySpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion ,
          service="mina-daemon-instrumented",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}-instrumented-docker-image",
          extra_args="--build-arg service=mina-instrumented"
        }

        in

        DockerImage.generateStep daemonBerkeleySpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion,
          service="mina-archive-instrumented",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="archive-${DebianVersions.lowerName debVersion}-instrumented-docker-image",
          extra_args="--build-arg service=mina-archive-instrumented"
        }
        
        in

        DockerImage.generateStep archiveSpec

      ]
    }

in
{
  bullseye  = pipeline DebianVersions.DebVersion.Bullseye
}
