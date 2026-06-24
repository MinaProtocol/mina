let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let network = Network.Type.Devnet

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/RosettaIntegrationTests" "dhall"
      , S.strictlyStart (S.contains "buildkite/scripts/tests/rosetta")
      , S.exactly "buildkite/scripts/debian/install" "sh"
      , S.exactly "buildkite/scripts/debian/restore-or-install" "sh"
      , S.strictlyStart (S.contains "buildkite/scripts/apps")
      , S.strictlyStart (S.contains "scripts/debian")
      ]

let bareBinaries =
          "mina_testnet_signatures.exe:mina"
      ++  ",archive.exe:mina-archive"
      ++  ",rosetta_testnet_signatures.exe:mina-rosetta"
      ++  ",signer_testnet_signatures.exe:mina-ocaml-signer"
      ++  ",zkapp_test_transaction.exe:mina-zkapp-test-transaction"
      ++  ",indexer_test.exe:mina-rosetta-indexer-test"
      ++  ",libp2p_helper:libp2p_helper"

let envExports =
      [ "MINA_NETWORK_DEB=${Network.lowerName network}"
      , "MINA_DEB_CODENAME=bullseye"
      , "APPS_NETWORK=${Network.lowerName network}"
      , "APPS_BARE_BINARIES=${bareBinaries}"
      ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = dirtyWhen
        , path = "Test"
        , name = "RosettaIntegrationTests"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Test
          , PipelineTag.Type.Stable
          , PipelineTag.Type.Rosetta
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                  [ Cmd.run
                      "export MINA_DEB_CODENAME=bullseye && source ./buildkite/scripts/export-git-env-vars.sh && echo \\\${MINA_DOCKER_TAG}"
                  ]
                # RunInToolchain.runInToolchainBullseye
                    envExports
                    "buildkite/scripts/tests/rosetta/integration-tests.sh"
            , label = "Rosetta integration tests Bullseye"
            , key = "rosetta-integration-tests-bullseye"
            , target = Size.Small
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            , depends_on =
                DebianVersions.dependsOn
                  DebianVersions.DepsSpec::{
                  , network = network
                  , profile = Profiles.Type.Devnet
                  }
            }
        ]
      }
