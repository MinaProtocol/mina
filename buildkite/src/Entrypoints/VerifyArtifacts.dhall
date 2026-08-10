-- Verify Artifacts
--
-- One entrypoint for two scheduled checks against what we have already published.
-- Both run against the live repository and registry, so neither needs a build.
--
--   Infra      A canary, cheap enough to run every hour. It asks whether the apt
--              repository is serving a valid, non-empty index for every codename
--              and component, and whether the docker registry answers. An index
--              that returns 200 with zero packages counts as a failure, because
--              apt reports no error and users simply find nothing.
--
--   Artifacts  The full daily test. It installs each package in a clean container
--              of every codename, pulls each docker image, and installs the
--              automode metapackage with no version pin. The unpinned install is
--              the case that catches a dependency the channel cannot satisfy.
--
-- Everything else is passed through Buildkite environment variables, so a
-- scheduled build can change the package list, the channel or the codenames
-- without a change to this file. See buildkite/scripts/verify/run-verification.sh
-- for the full list of variables.

let Cmd = ../Lib/Cmds.dhall

let Command = ../Command/Base.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

let Size = ../Command/Size.dhall

let Mode = < Infra | Artifacts >

let modeName =
      \(mode : Mode) -> merge { Infra = "infra", Artifacts = "artifacts" } mode

let modeLabel =
          \(mode : Mode)
      ->  merge
            { Infra = "Infrastructure canary"
            , Artifacts = "Published artifact tests"
            }
            mode

let modeArtifactPaths =
          \(mode : Mode)
      ->  merge
            { Infra = [] : List SelectFiles.Type
            , Artifacts =
              [ SelectFiles.contains "verification-results/results.tsv"
              , SelectFiles.contains "verification-results/logs/*.log"
              ]
            }
            mode

let verifyCmd =
          \(mode : Mode)
      ->  Cmd.run
            (     "VERIFY_MODE=${modeName mode} "
              ++  "./buildkite/scripts/verify/run-verification.sh"
            )

let verify =
          \(mode : Mode)
      ->  let steps = [ verifyCmd mode ]

          let pipeline =
                Pipeline.build
                  Pipeline.Config::{
                  , spec = JobSpec::{
                    , dirtyWhen = [ SelectFiles.everything ]
                    , path = "Entrypoints"
                    , name = "VerifyArtifacts"
                    , tags =
                      [ PipelineTag.Type.Test
                      , PipelineTag.Type.Debian
                      , PipelineTag.Type.Docker
                      ]
                    }
                  , steps =
                    [ Command.build
                        Command.Config::{
                        , commands = steps
                        , label = "Verify: ${modeLabel mode}"
                        , key = "verify-${modeName mode}"
                        , target = Size.Small
                        , artifact_paths = modeArtifactPaths mode
                        }
                    ]
                  }

          in  pipeline.pipeline

in  { Mode = Mode, verify = verify }
