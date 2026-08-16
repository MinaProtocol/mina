-- Build only the steps that were asked for.
--
-- This is the shape RunSingleJob.dhall uses: the choice arrives as text, this
-- file emits one step, and a script does the work. Nothing is chosen here,
-- because Dhall cannot look at text: the Prelude of this repository has no
-- Text.split, and Dhall has no equality for Text at all.
--
-- The selection is a list of patterns for step keys, separated by commas. A key
-- holds what is built, for which tier and for which network
-- (rosetta_config-devnet-docker-image), and the name of the job holds the
-- codename and the architecture, so the whole key names one step of one
-- pipeline. select_steps.sh adds every step that the chosen ones depend on.

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

let commands
    : Text -> Cmd.Type
    =     \(selection : Text)
      ->  Cmd.run
            (     "./buildkite/scripts/entrypoints/run-selection.sh"
              ++  " --selection '"
              ++  selection
              ++  "'"
              ++  " --jobs ./buildkite/src/gen"
              ++  " --debug "
            )

in      \(args : { selection : Text })
    ->  let pipelineType =
              Pipeline.build
                Pipeline.Config::{
                , spec = JobSpec::{
                  , name = "run-selection"
                  , dirtyWhen = [ SelectFiles.everything ]
                  }
                , steps =
                  [ Command.build
                      Command.Config::{
                      , commands = prefixCommands # [ commands args.selection ]
                      , label = "Run selection ${args.selection}"
                      , key = "cmds"
                      , target = Size.Multi
                      , docker = Some Docker::{
                        , image =
                            (../Constants/ContainerImages.dhall).toolchainBase
                        , environment =
                          [ "BUILDKITE_AGENT_ACCESS_TOKEN"
                          , "BUILDKITE_INCREMENTAL"
                          ]
                        }
                      }
                  ]
                }

        in  pipelineType.pipeline
