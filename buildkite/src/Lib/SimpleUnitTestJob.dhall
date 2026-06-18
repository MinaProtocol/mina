let S = ../Lib/SelectFiles.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Command = ../Command/Base.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let Docker = ../Command/Docker/Type.dhall

let Size = ../Command/Size.dhall

let Config
    : Type
    = { name : Text
      , keyPrefix : Text
      , label : Text
      , testProfile : Text
      , testPath : Text
      , tags : List PipelineTag.Type
      , cmdTarget : Size
      }

let build
    : Config -> Pipeline.CompoundType
    =     \(c : Config)
      ->  let key = "${c.keyPrefix}-unit-test-${c.testProfile}"

          let buildTestCmd
              : Size -> Command.Type
              =     \(cmd_target : Size)
                ->  Command.build
                      Command.Config::{
                      , commands =
                          RunInToolchain.runInToolchain
                            [ "DUNE_INSTRUMENT_WITH=bisect_ppx"
                            , "COVERALLS_TOKEN"
                            ]
                            "buildkite/scripts/unit-test.sh ${c.testProfile} ${c.testPath} && buildkite/scripts/upload-partial-coverage-data.sh ${key} dev"
                      , label = c.label
                      , key = key
                      , target = cmd_target
                      , docker = None Docker.Type
                      , artifact_paths = [ S.contains "core_dumps/*" ]
                      }

          in  Pipeline.build
                Pipeline.Config::{
                , spec = JobSpec::{
                  , dirtyWhen =
                    [ S.strictlyStart (S.contains "src")
                    , S.exactly "buildkite/src/Jobs/Test/${c.name}" "dhall"
                    , S.exactly "buildkite/scripts/unit-test" "sh"
                    ]
                  , path = "Test"
                  , name = c.name
                  , tags = c.tags
                  }
                , steps = [ buildTestCmd c.cmdTarget ]
                }

in  { Config = Config, build = build }
