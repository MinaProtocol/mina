let Cmd = ../../Lib/Cmds.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let RunWithPostgres = ../../Command/RunWithPostgres.dhall

let ContainerImages = ../../Constants/ContainerImages.dhall

let Arch = ../../Constants/Arch.dhall

let Network = ../../Constants/Network.dhall

let network = Network.Type.Devnet

let dirtyWhen =
      [ S.strictlyStart (S.contains "src")
      , S.exactly "buildkite/src/Jobs/Test/RosettaIntegrationTests" "dhall"
      , S.exactly "buildkite/scripts/tests/rosetta/integration-tests" "sh"
      , S.exactly "buildkite/scripts/tests/rosetta/install-debs" "sh"
      , S.exactly "buildkite/scripts/tests/rosetta/install-cli" "sh"
      , S.exactly "buildkite/scripts/tests/rosetta/indexer-test" "sh"
      , S.exactly "buildkite/scripts/debian/install" "sh"
      , S.strictlyStart (S.contains "scripts/debian")
      ]

let envExports =
      [ "MINA_NETWORK_DEB=${Network.lowerName network}"
      , "MINA_DEB_CODENAME=bullseye"
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
                  , RunWithPostgres.runInDockerWithPostgresConn
                      envExports
                      ( Some
                          ( RunWithPostgres.ScriptOrArchive.Script
                              "./src/test/archive/sample_db/archive_db.sql"
                          )
                      )
                      ContainerImages.minaToolchainBullseye.amd64
                      "./buildkite/scripts/tests/rosetta/indexer-test.sh"
                  ]
                # RunInToolchain.runInToolchainBullseye
                    Arch.Type.Amd64
                    envExports
                    "buildkite/scripts/tests/rosetta/integration-tests.sh"
            , label = "Rosetta integration tests Bullseye"
            , key = "rosetta-integration-tests-bullseye"
            , target = Size.Small
            , artifact_paths = [ S.contains "test_output/artifacts/*" ]
            , depends_on = DebianVersions.dependsOn DebianVersions.DepsSpec::{=}
            }
        ]
      }
