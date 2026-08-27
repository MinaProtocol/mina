-- Build the artifacts that were asked for, and nothing else.
--
-- THIS IS THE ENTRYPOINT OF AN ARTIFACT BUILD, and it is deliberately not
-- reachable from Prepare.dhall. An artifact build and a CI run are different
-- things: CI decides what to run by triaging a diff against tags, scopes and
-- dirty-when, while an artifact build is started by someone who has said what
-- they want. Putting the two behind one entrypoint would mean every ordinary CI
-- run carried the machinery of a selection, and one stray environment variable
-- would turn a CI run into an artifact build.
--
-- So a pipeline is configured with either Prepare.dhall (CI) or this file
-- (artifacts), the same way GenerateHardforkPackage.dhall and
-- RunSingleJob.dhall have pipelines of their own. Nothing here triages.
--
-- Nothing is chosen here either, because Dhall cannot look at text: the Prelude
-- of this repository has no Text.split, and Dhall has no equality for Text at
-- all. One step is emitted and a script does the work.
--
-- The choice arrives in BUILDKITE_PIPELINE_SELECTION, a list of patterns for
-- step keys separated by commas, and in BUILDKITE_PIPELINE_DEB_SELECTION, the
-- same for debian package tokens. A step key holds what is built, for which
-- tier and for which network (rosetta_config-devnet-docker-image), and the name
-- of the job holds the codename and the architecture, so a whole key names one
-- step of one pipeline. select_steps.sh adds every step the chosen ones depend
-- on.
--
-- Naming nothing builds the whole layer, because someone typing !ci-docker-me
-- asked for docker images and there is no triage here to fall back on.
--
-- The value is written by whoever wrote the pull request comment, and it is
-- deliberately NOT read here. Dhall can read the environment, so a value put
-- into a dhall expression that closed its quote would evaluate on the agent.
-- Passing it in the environment instead leaves nothing to escape from.
--
-- A pipeline that uses this file is configured with:
--
--   dhall-to-yaml --quoted <<< "./buildkite/src/Entrypoints/RunSelection.dhall" \
--     | buildkite-agent pipeline upload

let SelectFiles = ../Lib/SelectFiles.dhall

let Cmd = ../Lib/Cmds.dhall

let Command = ../Command/Base.dhall

let Docker = ../Command/Docker/Type.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let Size = ../Command/Size.dhall

let prefixCommands =
      [ Cmd.run
          "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt"
      , Cmd.run "./buildkite/scripts/refresh_code.sh"
      , Cmd.run
          "./buildkite/scripts/dhall/dump_dhall_to_pipelines.sh ./buildkite/src buildkite/src/gen"
      ]

let commands =
      Cmd.run
        "./buildkite/scripts/entrypoints/run-selection.sh --jobs ./buildkite/src/gen --debug "

let config
    : Pipeline.Config.Type
    = Pipeline.Config::{
      , spec = JobSpec::{
        , name = "run-selection"
        , dirtyWhen = [ SelectFiles.everything ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = prefixCommands # [ commands ]
            , label = "Run selection"
            , key = "cmds"
            , target = Size.Multi
            , docker = Some Docker::{
              , image = (../Constants/ContainerImages.dhall).toolchainBase
              , environment =
                [ "BUILDKITE_AGENT_ACCESS_TOKEN"
                , "BUILDKITE_INCREMENTAL"
                , "BUILDKITE_PIPELINE_SELECTION"
                , "BUILDKITE_PIPELINE_DEB_SELECTION"
                ]
              }
            }
        ]
      }

in  (Pipeline.build config).pipeline
