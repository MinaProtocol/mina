let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Profiles = ../../Constants/Profiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let DockerImage = ../../Command/DockerImage.dhall

let Size = ../../Command/Size.dhall

let profile = Profiles.Type.Standard

let debVersion = DebianVersions.DebVersion.Bullseye

let network = "mainnet-hardfork"

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
---       name = "GenerateLedgerTarsFromConfig",
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

in  Pipeline.build
      Pipeline.Config::{
        spec = JobSpec::{
          dirtyWhen = [ S.everything ]
        , path = "Release"
        , name = "GenerateLedgerTarsFromConfig"
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
                  ]
                  "./buildkite/scripts/build-hardfork-package2.sh"
            , label = "Ledger tar file generation"
            , key = "generate-ledger-tars-from-config"
            , target = Size.XLarge
            }
        , DockerImage.generateStep
            DockerImage.ReleaseSpec::{
              deps =
              [ { name = "GenerateLedgerTarsFromConfig"
                , key = "generate-ledger-tars-from-config"
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
