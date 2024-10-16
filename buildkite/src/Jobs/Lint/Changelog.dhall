let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let triggerChange = S.compile [ S.strictlyStart (S.contains "src") ]

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "src"
          , S.exactly "buildkite/src/Jobs/Lint/Changlelog" "dhall"
          ]
        , path = "Lint"
        , name = "Changelog"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt"
              , Cmd.run "./buildkite/scripts/refresh_code.sh"
              , Cmd.run
                  "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
              , Cmd.run
                  ''
                      if (cat _computed_diff.txt | egrep -q '${triggerChange}'); then
                          if ! (cat _computed_diff.txt | egrep -q 'Changelog.md'); then
                              echo "Missing changelog entry detected for this change"
                              exit 1
                          fi
                      fi
                  ''
              ]
            , label = "Lint: Changelog"
            , key = "lint-changelog"
            , target = Size.Multi
            }
        ]
      }
