let Prelude = ./External/Prelude.dhall

let List/map = Prelude.List.map

let SelectFiles = ./Lib/SelectFiles.dhall

let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall

let Docker = ./Command/Docker/Type.dhall

let JobSpec = ./Pipeline/JobSpec.dhall

let Pipeline = ./Pipeline/Dsl.dhall

let PipelineMode = ./Pipeline/Mode.dhall

let PipelineFilter = ./Pipeline/Filter.dhall

let PipelineTag = ./Pipeline/Tag.dhall

let Size = ./Command/Size.dhall

let triggerCommand = ./Pipeline/TriggerCommand.dhall

let jobs
    : List JobSpec.Type
    = List/map
        Pipeline.CompoundType
        JobSpec.Type
        (\(composite : Pipeline.CompoundType) -> composite.spec)
        ./gen/Jobs.dhall

let prefixCommands =
      [ Cmd.run
          "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt"
      , Cmd.run "./buildkite/scripts/refresh_code.sh"
      , Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
      ]

let commands
    : PipelineFilter.Type -> PipelineMode.Type -> List Cmd.Type
    =     \(filter : PipelineFilter.Type)
      ->  \(mode : PipelineMode.Type)
      ->  List/map
            JobSpec.Type
            Cmd.Type
            (     \(job : JobSpec.Type)
              ->  let targetMode = PipelineMode.capitalName mode

                  let targetTags = PipelineFilter.tags filter

                  let filter = PipelineFilter.show filter

                  let isIncluded =
                        Prelude.Bool.show
                          (PipelineTag.contains job.tags targetTags)

                  let dirtyWhen = SelectFiles.compile job.dirtyWhen

                  let trigger =
                        triggerCommand "src/Jobs/${job.path}/${job.name}.dhall"

                  let pipelineHandlers =
                        { PullRequest =
                            ''
                              if [ "${targetMode}" == "PullRequest" ]; then
                                if [ "${isIncluded}" == "True" ]; then
                                  if (cat _computed_diff.txt | egrep -q '${dirtyWhen}'); then
                                    echo "Triggering ${job.name} for reason:"
                                    cat _computed_diff.txt | egrep '${dirtyWhen}'
                                    ${Cmd.format trigger}
                                  fi
                                else
                                  echo "Skipping ${job.name} because this is a ${filter} stage"
                                fi
                              elif [ "${targetMode}" == "Stable" ]; then
                                if [ "${isIncluded}" == "True" ]; then
                                  echo "Triggering ${job.name} because this is a stable buildkite run"
                                  ${Cmd.format trigger}
                                else 
                                  echo "Skipping ${job.name} because this is a ${filter} stage"
                                fi
                              else
                                echo "Skipping ${job.name} because this is a stable buildkite run"
                              fi
                            ''
                        , Stable =
                            ''
                              if [ "${targetMode}" == "Stable" ]; then
                                if [ "${isIncluded}" == "True" ]; then
                                  echo "Triggering ${job.name} because this is a stable buildkite run"
                                  ${Cmd.format trigger}
                                else
                                  echo "Skipping ${job.name} because this is a ${filter} stage"
                                fi
                              else
                                echo "Skipping ${job.name} because this is a PR buildkite run"
                              fi
                            ''
                        }

                  in  Cmd.quietly (merge pipelineHandlers job.mode)
            )
            jobs

in      \(args : { filter : PipelineFilter.Type, mode : PipelineMode.Type })
    ->  let pipelineType =
              Pipeline.build
                Pipeline.Config::{
                , spec = JobSpec::{
                  , name = "monorepo-triage-${PipelineFilter.show args.filter}"
                  , dirtyWhen = [ SelectFiles.everything ]
                  }
                , steps =
                  [ Command.build
                      Command.Config::{
                      , commands =
                          prefixCommands # commands args.filter args.mode
                      , label =
                          "Monorepo triage ${PipelineFilter.show args.filter}"
                      , key = "cmds-${PipelineFilter.show args.filter}"
                      , target = Size.Small
                      , docker = Some Docker::{
                        , image =
                            (./Constants/ContainerImages.dhall).toolchainBase
                        , environment =
                          [ "BUILDKITE_AGENT_ACCESS_TOKEN"
                          , "BUILDKITE_INCREMENTAL"
                          ]
                        }
                      }
                  ]
                }

        in  pipelineType.pipeline
