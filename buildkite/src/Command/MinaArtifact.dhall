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

in

let HardforkPipelineMode  = < ForTest | ForRelease >

let fromEnvOrTest = \(mode : HardforkPipelineMode) -> \(envVar : Text) -> \(default : Text) ->
  merge { ForRelease = "${envVar}=\$${envVar}", ForTest = "${envVar}=${default}" } mode


--- NB: unlike the regular artifact piopeline, the hardfork pipeline receives many of its parameters as env vars
let hardforkPipeline : HardforkPipelineMode -> DebianVersions.DebVersion ->  Pipeline.Config.Type =
  \(hardforkPipelineMode : HardforkPipelineMode) ->
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
      let network = "\\\${NETWORK_NAME}-hardfork"
      let hfmode = merge { ForTest = "Test" , ForRelease = "Release" } hardforkPipelineMode
      let pipelineName = "MinaArtifactHardfork${DebianVersions.capitalName debVersion}${Profiles.toSuffixUppercase profile}${hfmode}"
      let generateLedgersJobKey = "generate-ledger-tars-from-config"
      let fromEnvOrTest = fromEnvOrTest hardforkPipelineMode
      in
  
      Pipeline.Config::{
        spec = JobSpec::{
          dirtyWhen = [ S.everything ]
        , path = hfmode
        , name = pipelineName
        , tags = [ PipelineTag.Type.Release ]
        , mode = merge { ForRelease = PipelineMode.Type.PackageGeneration, ForTest = PipelineMode.Type.Stable } hardforkPipelineMode
        }
      , steps =
        [ Command.build
            Command.Config::{
              commands =
                DebianVersions.toolchainRunner
                  debVersion
                  [ fromEnvOrTest "NETWORK_NAME" "devnet"
                  , fromEnvOrTest "CONFIG_JSON_GZ_URL" "https://storage.googleapis.com/tmp-hardfork-testing/fork-devnet-march-22-2024.json.gz"
                  , "AWS_ACCESS_KEY_ID"
                  , "AWS_SECRET_ACCESS_KEY"
                  , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                  , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                  , "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}"
                  , "TESTNET_NAME=\$NETWORK_NAME-hardfork-${hfmode}"
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
                } "curl \$CONFIG_JSON_GZ_URL > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config config.json /workdir/verification"
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

let docker_step : Artifacts.Type -> DebianVersions.DebVersion -> Profiles.Type -> DockerImage.ReleaseSpec.Type = 
  \(artifact : Artifacts.Type) ->
  \(debVersion : DebianVersions.DebVersion) ->
  \(profile : Profiles.Type) ->
  merge {
        Daemon = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-daemon",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          },

        TestExecutive = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-test-executive",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="test-executive-${DebianVersions.lowerName debVersion}-docker-image"
          },

        BatchTxn = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-batch-txn",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="batch-txn-${DebianVersions.lowerName debVersion}-docker-image"
          },

        Archive = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-archive",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="archive-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          },

        ArchiveMigration = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-archive-migration",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="archive-migration-${DebianVersions.lowerName debVersion}-docker-image"
          },
          
        Rosetta = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-rosetta",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="rosetta-${DebianVersions.lowerName debVersion}-docker-image"
          },

        ZkappTestTransaction = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-zkapp-test-transaction",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          },
        
        FunctionalTestSuite = 
          DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-test-suite",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="test-suite-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image",
            network="berkeley"
          }
      } artifact
in 

let pipeline : List Artifacts.Type -> DebianVersions.DebVersion  -> Profiles.Type ->  PipelineMode.Type -> Pipeline.Config.Type = 
  \(artifacts: List Artifacts.Type) ->
  \(debVersion : DebianVersions.DebVersion) ->
  \(profile: Profiles.Type) ->
  \(mode: PipelineMode.Type) ->
    let steps = [
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
            ] "./buildkite/scripts/build-release.sh ${Artifacts.toDebianNames artifacts}",
            label = "Build Mina for ${DebianVersions.capitalName debVersion} ${Profiles.toSuffixUppercase profile}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          }
      ] # (List/map
            Artifacts.Type
            Command.Type
            (\(artifact : Artifacts.Type) ->  DockerImage.generateStep (docker_step artifact debVersion profile) )
            artifacts)
    in

    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen debVersion,
          path = "Release",
          name = "MinaArtifact${DebianVersions.capitalName debVersion}${Profiles.toSuffixUppercase profile}",
          tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ],
          mode = mode
        },
      steps = steps    }

in
{
  pipeline = pipeline
  , hardforkPipeline = hardforkPipeline
  , HardforkPipelineMode/Type = HardforkPipelineMode
}
