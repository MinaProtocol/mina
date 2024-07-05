let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Size = ./Size.dhall

let Libp2p = ./Libp2pHelperBuild.dhall

let DockerImage = ./DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let Profiles = ../Constants/Profiles.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Artifacts = ../Constants/Artifacts.dhall

let Toolchain = ../Constants/Toolchain.dhall

let docker_step
    :     Artifacts.Type
      ->  DebianVersions.DebVersion
      ->  Profiles.Type
      ->  BuildFlags.Type
      ->  DockerImage.ReleaseSpec.Type
    =     \(artifact : Artifacts.Type)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(profile : Profiles.Type)
      ->  \(buildFlags : BuildFlags.Type)
      ->  let step_dep_name = "build"

          in  merge
                { Daemon = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-daemon"
                  , network = "berkeley"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_profile = profile
                  , build_flags = buildFlags
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "daemon-berkeley-${DebianVersions.lowerName
                                           debVersion}${Profiles.toLabelSegment
                                                          profile}${BuildFlags.toLabelSegment
                                                                      buildFlags}-docker-image"
                  }
                , TestExecutive = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-test-executive"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "test-executive-${DebianVersions.lowerName
                                          debVersion}-docker-image"
                  }
                , BatchTxn = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-batch-txn"
                  , network = "berkeley"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "batch-txn-${DebianVersions.lowerName
                                     debVersion}-docker-image"
                  }
                , Archive = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-archive"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_profile = profile
                  , build_flags = buildFlags
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "archive-${DebianVersions.lowerName
                                   debVersion}${Profiles.toLabelSegment
                                                  profile}${BuildFlags.toLabelSegment
                                                              buildFlags}-docker-image"
                  }
                , ArchiveMigration = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-archive-migration"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_profile = profile
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "archive-migration-${DebianVersions.lowerName
                                             debVersion}-docker-image"
                  }
                , Rosetta = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-rosetta"
                  , network = "berkeley"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "rosetta-${DebianVersions.lowerName
                                   debVersion}${BuildFlags.toLabelSegment
                                                  buildFlags}-docker-image"
                  }
                , ZkappTestTransaction = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-zkapp-test-transaction"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "zkapp-test-transaction-${DebianVersions.lowerName
                                                  debVersion}${Profiles.toLabelSegment
                                                                 profile}${BuildFlags.toLabelSegment
                                                                             buildFlags}-docker-image"
                  }
                , FunctionalTestSuite = DockerImage.ReleaseSpec::{
                  , deps =
                      DebianVersions.dependsOnStep
                        debVersion
                        profile
                        buildFlags
                        step_dep_name
                  , service = "mina-test-suite"
                  , deb_codename = "${DebianVersions.lowerName debVersion}"
                  , deb_repo = DebianRepo.Type.Local
                  , step_key =
                      "test-suite-${DebianVersions.lowerName
                                      debVersion}${Profiles.toLabelSegment
                                                     profile}-docker-image"
                  , network = "berkeley"
                  }
                }
                artifact

let MinaBuildSpec =
      { Type =
          { prefix : Text
          , artifacts : List Artifacts.Type
          , debVersion : DebianVersions.DebVersion
          , profile : Profiles.Type
          , buildFlags : BuildFlags.Type
          , toolchainSelectMode : Toolchain.SelectionMode
          , mode : PipelineMode.Type
          }
      , default =
          { prefix = "MinaArtifact"
          , artifacts = Artifacts.AllButTests
          , debVersion = DebianVersions.DebVersion.Bullseye
          , profile = Profiles.Type.Standard
          , buildFlags = BuildFlags.Type.None
          , toolchainSelectMode = Toolchain.SelectionMode.ByDebian
          , mode = PipelineMode.Type.PullRequest
          }
      }

let build_artifacts =
          \(spec : MinaBuildSpec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                  Toolchain.select
                    spec.toolchainSelectMode
                    spec.debVersion
                    (   [ "DUNE_PROFILE=${Profiles.duneProfile spec.profile}"
                        , "AWS_ACCESS_KEY_ID"
                        , "AWS_SECRET_ACCESS_KEY"
                        , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                        , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                        , "MINA_DEB_CODENAME=${DebianVersions.lowerName
                                                 spec.debVersion}"
                        ]
                      # BuildFlags.buildEnvs spec.buildFlags
                    )
                    "./buildkite/scripts/build-release.sh ${Artifacts.toDebianNames
                                                              spec.artifacts}"
                # [ Cmd.run
                      "./buildkite/scripts/upload-deb-to-gs.sh ${DebianVersions.lowerName
                                                                   spec.debVersion}"
                  ]
            , label =
                "Build Mina for ${DebianVersions.capitalName
                                    spec.debVersion} ${Profiles.toSuffixUppercase
                                                         spec.profile} ${BuildFlags.toSuffixUppercase
                                                                           spec.buildFlags}"
            , key = "build-deb-pkg"
            , target = Size.XLarge
            , retries =
              [ Command.Retry::{
                , exit_status = Command.ExitStatus.Code +2
                , limit = Some 2
                }
              ]
            }
        , Command.build Command.Config::{
            commands = [
                Cmd.runInDocker Cmd.Docker::{ 
                  image = "gcr.io/o1labs-192920/mina-daemon:\${BUILDKITE_COMMIT:0:7}-${DebianVersions.lowerName debVersion}-${network}"
                , extraEnv = [ "CONFIG_JSON_GZ_URL=\$CONFIG_JSON_GZ_URL",  "NETWORK_NAME=\$NETWORK_NAME", "PRECOMPUTED_BLOCK_GS_PREFIX=\$PRECOMPUTED_BLOCK_GS_PREFIX" ]
                -- an account with this balance seems present in many ledgers?
                } "curl \$CONFIG_JSON_GZ_URL > config.json.gz && gunzip config.json.gz && sed -e '0,/20.000001/{s/20.000001/20.01/}' -i config.json && ! (mina-verify-packaged-fork-config \$NETWORK_NAME config.json /workdir/verification {PRECOMPUTED_BLOCK_GS_PREFIX:-})"
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
                , extraEnv = [ "CONFIG_JSON_GZ_URL=\$CONFIG_JSON_GZ_URL",  "NETWORK_NAME=\$NETWORK_NAME", "PRECOMPUTED_BLOCK_GS_PREFIX=\$PRECOMPUTED_BLOCK_GS_PREFIX" ]
                } "curl \$CONFIG_JSON_GZ_URL > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config \$NETWORK_NAME config.json /workdir/verification \${PRECOMPUTED_BLOCK_GS_PREFIX:-}"
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


let MinaBuildSpec = {
  Type = {
    prefix: Text,
    artifacts: List Artifacts.Type,
    debVersion : DebianVersions.DebVersion,
    profile: Profiles.Type,
    networks: List Network.Type,
    toolchainSelectMode: Toolchain.SelectionMode,
    mode: PipelineMode.Type,
    tags: List PipelineTag.Type
  },
  default = {
    prefix = "MinaArtifact",
    artifacts = Artifacts.AllButTests,
    debVersion = DebianVersions.DebVersion.Bullseye,
    profile = Profiles.Type.Standard,
    networks = [ Network.Type.Berkeley ],
    toolchainSelectMode = Toolchain.SelectionMode.ByDebian,
    mode = PipelineMode.Type.PullRequest,
    tags = [ PipelineTag.Type.Long, PipelineTag.Type.Release ]
  }
}

let docker_step : Artifacts.Type -> DebianVersions.DebVersion -> List Network.Type -> Profiles.Type -> List DockerImage.ReleaseSpec.Type = 
  \(artifact : Artifacts.Type) ->
  \(debVersion : DebianVersions.DebVersion) ->
  \(networks : List Network.Type) ->
  \(profile : Profiles.Type) ->
  merge {
        Daemon = 
            Prelude.List.map
                  Network.Type
                  DockerImage.ReleaseSpec.Type
                  (\(n: Network.Type) -> 
                     DockerImage.ReleaseSpec::{
                      deps=DebianVersions.dependsOn debVersion profile,
                      service="mina-daemon",
                      network=Network.lowerName n,
                      deb_codename="${DebianVersions.lowerName debVersion}",
                      deb_profile="${Profiles.lowerName profile}",
                      step_key="daemon-${Network.lowerName n}-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
                    }
                  )
                  networks
          ,

        TestExecutive = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-test-executive",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="test-executive-${DebianVersions.lowerName debVersion}-docker-image"
          }],

        BatchTxn = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-batch-txn",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="batch-txn-${DebianVersions.lowerName debVersion}-docker-image"
          }],

        Archive = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-archive",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="archive-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          }],

        ArchiveMigration = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-archive-migration",
            deb_codename="${DebianVersions.lowerName debVersion}",
            deb_profile="${Profiles.lowerName profile}",
            step_key="archive-migration-${DebianVersions.lowerName debVersion}-docker-image"
          }],
          
        Rosetta = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-rosetta",
            network="berkeley",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="rosetta-${DebianVersions.lowerName debVersion}-docker-image"
          }],

        ZkappTestTransaction = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-zkapp-test-transaction",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="zkapp-test-transaction-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
          }],
        
        FunctionalTestSuite = 
          [DockerImage.ReleaseSpec::{
            deps=DebianVersions.dependsOn debVersion profile,
            service="mina-test-suite",
            deb_codename="${DebianVersions.lowerName debVersion}",
            step_key="test-suite-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image",
            network="berkeley"
          }]
      } artifact

let docker_commands : MinaBuildSpec.Type -> List Command.Type = 
        \(spec: MinaBuildSpec.Type) ->

       let docker_steps = List/map
              Artifacts.Type
              (List DockerImage.ReleaseSpec.Type)
              (\(artifact: Artifacts.Type) -> docker_step artifact spec.debVersion spec.networks spec.profile)
              spec.artifacts
      
      
      let flatten_docker_steps = 
           Prelude.List.fold
              (List DockerImage.ReleaseSpec.Type)
              docker_steps
              (List DockerImage.ReleaseSpec.Type)
              (\(x : List DockerImage.ReleaseSpec.Type) → \(y : List DockerImage.ReleaseSpec.Type) →  x # y)
              ([] : List DockerImage.ReleaseSpec.Type)
      in 

      (List/map
            DockerImage.ReleaseSpec.Type
            Command.Type
            (\(s: DockerImage.ReleaseSpec.Type) -> DockerImage.generateStep s)
            flatten_docker_steps)


let pipeline : MinaBuildSpec.Type -> Pipeline.Config.Type = 
  \(spec: MinaBuildSpec.Type) ->
    let steps = [
        Libp2p.step spec.debVersion,
        Command.build
          Command.Config::{
            commands = Toolchain.select spec.toolchainSelectMode spec.debVersion ([
              "DUNE_PROFILE=${Profiles.duneProfile spec.profile}",
              "AWS_ACCESS_KEY_ID",
              "AWS_SECRET_ACCESS_KEY",
              "MINA_BRANCH=$BUILDKITE_BRANCH",
              "MINA_COMMIT_SHA1=$BUILDKITE_COMMIT",
              "MINA_DEB_CODENAME=${DebianVersions.lowerName spec.debVersion}",
              Network.foldMinaBuildMainnetEnv spec.networks
            ]) "./buildkite/scripts/build-release.sh ${Artifacts.toDebianNames spec.artifacts spec.networks}",
            label = "Build Mina for ${DebianVersions.capitalName spec.debVersion} ${Profiles.toSuffixUppercase spec.profile}",
            key = "build-deb-pkg",
            target = Size.XLarge,
            retries = [
              Command.Retry::{
                exit_status = Command.ExitStatus.Code +2,
                limit = Some 2
              } ] -- libp2p error
          }
      ]
    
    in 
    
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen spec.debVersion,
          path = "Release",
          name = "${spec.prefix}${DebianVersions.capitalName spec.debVersion}${Profiles.toSuffixUppercase spec.profile}",
          tags = spec.tags,
          mode = spec.mode
        },
      steps = steps # docker_commands spec
    }

in
{
  pipeline = pipeline
  , MinaBuildSpec = MinaBuildSpec
  , hardforkPipeline = hardforkPipeline
}