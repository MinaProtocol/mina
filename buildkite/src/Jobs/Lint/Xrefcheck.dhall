let B = ../../External/Buildkite.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ SelectFiles.strictly SelectFiles::{ exts = Some [ "md" ] }
          , SelectFiles.strictlyStart
              (SelectFiles.contains "buildkite/src/Jobs/Lint/Xrefcheck.dhall")
          ]
        , path = "Lint"
        , name = "Xrefcheck"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
              [ Cmd.runInDocker
                  Cmd.Docker::{
                  , image = (../../Constants/ContainerImages.dhall).xrefcheck
                  }
                  (     "awesome_bot -allow-dupe "
                    ++  "--allow-redirect "
                    ++  "--allow 403,401 "
                    ++  "--skip-save-results "
                    ++  "--files "
                    ++  "`find . -name \"*.md\" "
                    ++  "! -path \"./src/lib/crypto/kimchi_bindings/*\" "
                    ++  "! -path \"./src/lib/crypto/proof-systems/*\" "
                    ++  "! -path \"./src/external/*\" "
                    ++  "` "
                  )
              ]
            , label = "Verifies references in markdown"
            , key = "xrefcheck"
            , target = Size.Small
            , soft_fail = Some (B/SoftFail.Boolean True)
            }
        ]
      }
