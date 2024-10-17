let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let trigger = S.compile [ S.strictlyStart (S.contains "src") ]

let reqFile = "^changes/\\\${BUILDKITE_PULL_REQUEST}-.*.md"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.contains "src"dkijania/changelog_job_check
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.run "./buildkite/scripts/refresh_code.sh"
              , Cmd.run "git clean -fd"
              , Cmd.run
                  "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
              , Cmd.run "cat _computed_diff.txt"
              , Cmd.quietly
                  ''
                      if (cat _computed_diff.txt | egrep -q '${trigger}'); then
                          if ! (cat _computed_diff.txt | egrep -q '${reqFile}'); then
                              echo "Missing changelog entry detected !!"
                              echo ""
                              echo "This job detected that you modified important part of code and did not update changelog file."
                              echo "Please ensure that you added this change to our changelog file: "
                              echo "'${reqFile}'"
                              echo " - from example: changes/\\\${BUILDKITE_PULL_REQUEST}-new-fancy-daemon-feature.md
                              echo "It will help us to produce Release Notes for upcoming release"
                              exit 1
                          else
                              echo "Changelog updated!"
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
