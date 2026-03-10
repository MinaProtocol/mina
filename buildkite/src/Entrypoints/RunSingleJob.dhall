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
    =     \(name : Text)
      ->  Cmd.run
            (     "./buildkite/scripts/run-single-job-with-deps.sh"
              ++  " --job-name "
              ++  name
              ++  " --jobs ./buildkite/src/gen"
              ++  " --debug "
            )

in      \(args : { name : Text })
    ->  let pipelineType =
              Pipeline.build
                Pipeline.Config::{
                , spec = JobSpec::{
                  , name = "run-single-job-${args.name}"
                  , dirtyWhen = [ SelectFiles.everything ]
                  }
                , steps =
                  [ Command.build
                      Command.Config::{
                      , commands = prefixCommands # [ commands args.name ]
                      , label = "Run Single Job ${args.name}"
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
