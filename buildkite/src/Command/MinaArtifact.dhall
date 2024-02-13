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

in

--- NB: unlike the regular artifact piopeline, the hardfork pipeline receives many of its parameters as env vars
let hardForkPipeline : DebianVersions.DebVersion -> Pipeline.Config.Type =
  \(debVersion : DebianVersions.DebVersion) ->
      --- TODO: Refactor the dhall interface so that we don't need to keep nesting docker containers.
      --- I've already refactored some of it such that everything works in the root docker contains,
      --- EXCEPT that the env secrets injection currently relies on the nested docker configuration.

      --- Once this is done, we can simplify the jobs quite a bit. Below is an example of this job
      --- after such a refactor has taken place. Note that the commands no longer need to be in a
      --- separate script, creating less indirection, and that we no longer need to do any weird
      --- docker nesting and environment passing. But this doesn't have access to any secrets as
      --- is, and it didn't seem that defining the env vars at the top layer fixed that.

      --- Pipeline.build
      ---   Pipeline.Config::{
      ---     spec = JobSpec::{
      ---       dirtyWhen = [S.everything],
      ---       path = "Release",
      ---       name = "MinaArtifactHardfork${DebianVersions.capitalName debVersion}${Profiles.toSuffixUppercase profile}"
      ---       tags = [ PipelineTag.Type.Release ],
      ---       mode = PipelineMode.Type.PackageGeneration
      ---     },
      ---     steps = [
      ---       Command.build
      ---         Command.Config::{
      ---           commands = [
      ---             Cmd.run "source ~/.profile"
      ---             , Cmd.run "curl -o config.json.gz $CONFIG_JSON_GZ_URL"
      ---             , Cmd.run "gunzip config.json.gz"
      ---             , Cmd.run "dune build src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe src/app/logproc/logproc.exe"
      ---             , Cmd.run "mkdir hardfork_ledgers"
      ---             , Cmd.run "_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json | tee runtime_genesis_ledger.log | _build/default/src/app/logproc/logproc.exe"
      ---             -- , Cmd.run ''
      ---             --     _build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file config.json --genesis-dir hardfork_ledgers/ --hash-output-file hardfork_ledger_hashes.json \
      ---             --     | tee runtime_genesis_ledger.log \
      ---             --     | _build/default/src/app/logproc/logproc.exe
      ---             --     ''
      ---             , Cmd.run "FORK_CONFIG_JSON=config.json LEDGER_HASHES_JSON=hardfork_ledger_hashes.json scripts/hardfork/create_runtime_config.sh > new_config.json"
      ---             , Cmd.run "ls hardfork_ledgers"
      ---             , Cmd.run "cat new_config.json"
      ---             , Cmd.run "MINA_DEB_CODENAME=bullseye MINA_BUILD_MAINNET=1 RUNTIME_CONFIG_JSON=new_config.json LEDGER_TARBALLS=\"$(echo hardfork_ledgers/*.tar.gz)\" ./buildkite/scripts/build-hardfork-package.sh"
      ---           ]
      ---           , docker = Some Docker::{
      ---             image = ContainerImages.minaToolchain
      ---             , shell = Some ["/bin/bash", "-e", "-c"]
      ---             , user = Some "root"
      ---           }
      ---           , label = "Ledger tar file generation"
      ---           , key = "generate-ledger-tars-from-config"
      ---           , target = Size.XLarge
      ---         }
      ---     ]
      ---   }

      --- TODO: profile is currently hard-coded for standard networks, but should be determined from env vars
      let profile = Profiles.Type.Standard
      --- TODO: network is currently hard-coded, but should be determined from env vars
      let network = "mainnet-hardfork"
      let pipelineName = "MinaArtifactHardfork${DebianVersions.capitalName debVersion}${Profiles.toSuffixUppercase profile}"
      let generateLedgersJobKey = "generate-ledger-tars-from-config"

      in
  
      Pipeline.Config::{
        spec = JobSpec::{
          dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = pipelineName
        , tags = [ PipelineTag.Type.Release ]
        , mode = PipelineMode.Type.PackageGeneration
        }
      , steps =
        [ Command.build
            Command.Config::{
              commands =
                DebianVersions.toolchainRunner
                  debVersion
                  [ "DUNE_PROFILE=\$DUNE_PROFILE"
                  , "CONFIG_JSON_GZ_URL=\$CONFIG_JSON_GZ_URL"
                  , "AWS_ACCESS_KEY_ID"
                  , "AWS_SECRET_ACCESS_KEY"
                  , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                  , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                  , "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}"
                  , "TESTNET_NAME=${network}"
                  , "GENESIS_TIMESTAMP=\$GENESIS_TIMESTAMP"
                  ]
                  "./buildkite/scripts/build-hardfork-package.sh"
            , label = "Ledger tar file generation"
            , key = generateLedgersJobKey
            , target = Size.XLarge
            }
        , DockerImage.generateStep
            DockerImage.ReleaseSpec::{
              deps =
              [ { name = pipelineName
                , key = generateLedgersJobKey
                }
              ]
            , service = "mina-daemon"
            , network = network
            , deb_codename = "${DebianVersions.lowerName debVersion}"
            , deb_profile = "${Profiles.lowerName profile}"
            , step_key = "daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
            }
        ]
      }

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
          step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
        }

        in

        DockerImage.generateStep daemonBerkeleySpec,

        -- test_executive image
        let testExecutiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-test-executive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="test-executive-${DebianVersions.lowerName debVersion}-docker-image",
          `if`=Some "'${Profiles.lowerName profile}' == 'standard'"
        }
        in
        DockerImage.generateStep testExecutiveSpec,

        -- batch_txn_tool image
        let batchTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-batch-txn",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="batch-txn-${DebianVersions.lowerName debVersion}-docker-image",
          `if`=Some "'${Profiles.lowerName profile}' == 'standard'"
        }
        in
        DockerImage.generateStep batchTxnSpec,

        -- archive image
        let archiveSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-archive",
          deb_codename="${DebianVersions.lowerName debVersion}",
          deb_profile="${Profiles.lowerName profile}",
          step_key="archive-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
        }
        in
        DockerImage.generateStep archiveSpec,

        -- rosetta image
        let rosettaSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-rosetta",
          network="berkeley",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="rosetta-${DebianVersions.lowerName debVersion}-docker-image",
          `if`=Some "'${Profiles.lowerName profile}' == 'standard'"
        }
        in
        DockerImage.generateStep rosettaSpec,

        -- ZkApp test transaction image
        let zkappTestTxnSpec = DockerImage.ReleaseSpec::{
          deps=DebianVersions.dependsOn debVersion profile,
          service="mina-zkapp-test-transaction",
          deb_codename="${DebianVersions.lowerName debVersion}",
          step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image",
          `if`=Some "'${Profiles.lowerName profile}' == 'standard'"
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
  , bullseyeHardfork = hardForkPipeline DebianVersions.DebVersion.Bullseye
  }
