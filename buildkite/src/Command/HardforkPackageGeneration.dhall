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

--- NB: unlike the regular artifact piopeline, the hardfork pipeline receives many of its parameters as env vars
let pipeline : DebianVersions.DebVersion -> Pipeline.Config.Type =
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
      ---             , Cmd.run "MINA_DEB_CODENAME=bullseye MINA_BUILD_MAINNET=true RUNTIME_CONFIG_JSON=new_config.json LEDGER_TARBALLS=\"$(echo hardfork_ledgers/*.tar.gz)\" ./buildkite/scripts/build-hardfork-package.sh"
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
      let network = "\\\${NETWORK_NAME}-hardfork"
      let pipelineName = "MinaArtifactHardfork${DebianVersions.capitalName debVersion}${Profiles.toSuffixUppercase profile}"
      let generateLedgersJobKey = "generate-ledger-tars-from-config"

      in
  
      Pipeline.Config::{
        spec = JobSpec::{
          dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = pipelineName
        , tags = [ PipelineTag.Type.Release, PipelineTag.Type.Hardfork, PipelineTag.Type.Long ]
        , mode = PipelineMode.Type.Stable
        }
      , steps =
        [ Command.build
            Command.Config::{
              commands =
                Toolchain.runner
                  debVersion
                  [ "NETWORK_NAME=\$NETWORK_NAME"
                  , "CONFIG_JSON_GZ_URL=\$CONFIG_JSON_GZ_URL"
                  , "AWS_ACCESS_KEY_ID"
                  , "AWS_SECRET_ACCESS_KEY"
                  , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                  , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                  , "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}"
                  , "TESTNET_NAME=\$NETWORK_NAME-hardfork"
                  , "GENESIS_TIMESTAMP=\$GENESIS_TIMESTAMP"
                  ]
                  "./buildkite/scripts/build-hardfork-package.sh"
            , label = "Build Mina Hardfork Package for ${DebianVersions.capitalName debVersion}"
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
        , Command.build Command.Config::{
            commands = [
                Cmd.runInDocker Cmd.Docker::{ 
                  image = "gcr.io/o1labs-192920/mina-daemon:\${BUILDKITE_COMMIT:0:7}-${DebianVersions.lowerName debVersion}-${network}"
                , extraEnv = [ "CONFIG_JSON_GZ_URL=\$CONFIG_JSON_GZ_URL",  "NETWORK_NAME=\$NETWORK_NAME" ]
                -- an account with this balance seems present in many ledgers?
                } "curl \$CONFIG_JSON_GZ_URL > config.json.gz && gunzip config.json.gz && sed -e '0,/20.000001/{s/20.000001/20.01/}' -i config.json && ! (mina-verify-packaged-fork-config \$NETWORK_NAME config.json /workdir/verification)"
            ]
            , label = "Assert corrupted packaged artifacts are unverifiable"
            , key = "assert-unverify-corrupted-packaged-artifacts"
            , target = Size.XLarge
            , depends_on = [{ name = pipelineName, key = "daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image" }]
            , `if` = None B/If
            }
        , Command.build Command.Config::{
            commands = [
                Cmd.runInDocker Cmd.Docker::{
                  image = "gcr.io/o1labs-192920/mina-daemon:\${BUILDKITE_COMMIT:0:7}-${DebianVersions.lowerName debVersion}-${network}"
                , extraEnv = [ "CONFIG_JSON_GZ_URL=\$CONFIG_JSON_GZ_URL",  "NETWORK_NAME=\$NETWORK_NAME" ]
                } "curl \$CONFIG_JSON_GZ_URL > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config \$NETWORK_NAME config.json /workdir/verification"
            ]
            , label = "Verify packaged artifacts"
            , key = "verify-packaged-artifacts"
            , target = Size.XLarge
            , depends_on = [{ name = pipelineName, key = "daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image" }]
            , `if` = None B/If
            }
        , DockerImage.generateStep
            DockerImage.ReleaseSpec::{
              deps =
              [ { name = pipelineName
                , key = generateLedgersJobKey
                }
              ]
            , service = "mina-archive"
            , network = network
            , deb_codename = "${DebianVersions.lowerName debVersion}"
            , deb_profile = "${Profiles.lowerName profile}"
            , step_key = "archive-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
            }
        , DockerImage.generateStep
            DockerImage.ReleaseSpec::{
              deps =
              [ { name = pipelineName
                , key = generateLedgersJobKey
                }
              ]
            , service = "mina-rosetta"
            , network = network
            , deb_codename = "${DebianVersions.lowerName debVersion}"
            -- , deb_profile = "${Profiles.lowerName profile}"
            , step_key = "rosetta-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
            }
        ]
      }

in
{
  pipeline = pipeline
}