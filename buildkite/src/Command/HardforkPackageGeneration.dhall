let Prelude = ../External/Prelude.dhall
let List/map = Prelude.List.map
let Optional/toList = Prelude.Optional.toList
let Optional/map = Prelude.Optional.map

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
let Network = ../Constants/Network.dhall

let Spec = {
  Type = {
    codename: DebianVersions.DebVersion,
    network: Network.Type,
    genesis_timestamp: Optional Text,
    config_json_gz_url: Text,
    profile: Profiles.Type,
    suffix: Text
  },
  default = {
    codename = DebianVersions.DebVersion.Bullseye,
    network = Network.Type.Devnet,
    genesis_timestamp = Some "2024-04-07T11:45:00Z",
    config_json_gz_url = "https://storage.googleapis.com/o1labs-gitops-infrastructure/devnet/devnet-state-dump-3NK4eDgbkCjKj9fFUXVkrJXsfpfXzJySoAvrFJVCropPW7LLF14F-676026c4d4d2c18a76b357d6422a06f932c3ef4667a8fd88717f68b53fd6b2d7.json.gz",
    profile = Profiles.Type.Standard,
    suffix = "hardfork"
  }
}

let spec_to_envs : Spec.Type -> List Text = 
  \(spec: Spec.Type ) -> 
  
  [
    "NETWORK_NAME=${Network.lowerName spec.network}",
    "TESTNET_NAME=${Network.lowerName spec.network}-${spec.suffix}",
    "CONFIG_JSON_GZ_URL=${spec.config_json_gz_url}"
  ]
  
  # 

  (Optional/toList
    Text
    (Optional/map
      Text
      Text
      (\(genesis_timestamp: Text) -> "GENESIS_TIMESTAMP=${genesis_timestamp}" )
      spec.genesis_timestamp)
  )

let pipeline : Spec.Type -> Pipeline.Config.Type =
      \(spec: Spec.Type) ->
      let profile = spec.profile
      let network = (Network.lowerName spec.network)
      let network_name = "${network}-hardfork"
      let pipelineName = "MinaArtifactHardfork${DebianVersions.capitalName spec.codename}${Profiles.toSuffixUppercase profile}"
      let generateLedgersJobKey = "generate-ledger-tars-from-config"
      let debVersion = spec.codename
      let image = image = "gcr.io/o1labs-192920/mina-daemon:\${BUILDKITE_COMMIT:0:7}-${DebianVersions.lowerName debVersion}-${network_name}"
      
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
                  (
                    [ "AWS_ACCESS_KEY_ID"
                    , "AWS_SECRET_ACCESS_KEY"
                    , "MINA_BRANCH=\$BUILDKITE_BRANCH"
                    , "MINA_COMMIT_SHA1=\$BUILDKITE_COMMIT"
                    , "MINA_DEB_CODENAME=${DebianVersions.lowerName debVersion}"
                    ]
                    # (spec_to_envs spec)
                  )
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
            , network = network_name
            , deb_codename = "${DebianVersions.lowerName debVersion}"
            , deb_profile = "${Profiles.lowerName profile}"
            , step_key = "daemon-berkeley-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
            }
        , Command.build Command.Config::{
            commands = [
                Cmd.runInDocker Cmd.Docker::{ 
                  image = image
                -- an account with this balance seems present in many ledgers?
                } "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && sed -e '0,/20.000001/{s/20.000001/20.01/}' -i config.json && ! (mina-verify-packaged-fork-config ${network} config.json /workdir/verification)"
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
                  image = image
                } "curl ${spec.config_json_gz_url} > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config ${network_name} config.json /workdir/verification"
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
            , network = network_name
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
            , network = network_name
            , deb_codename = "${DebianVersions.lowerName debVersion}"
            , step_key = "rosetta-${DebianVersions.lowerName debVersion}${Profiles.toLabelSegment profile}-docker-image"
            }
        ]
      }

in
{
  pipeline = pipeline,
  Spec = Spec
}