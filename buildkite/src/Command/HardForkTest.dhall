let B = ../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Cmd = ../Lib/Cmds.dhall

let Command = ./Base.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let Docker = ../Command/Docker/Type.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let S = ../Lib/SelectFiles.dhall

let Size = ./Size.dhall

in  { pipeline =
            \(name : Text)
        ->  \(label : Text)
        ->  \(key : Text)
        ->  \(extraArgs : Text)
        ->  Pipeline.build
              Pipeline.Config::{
              , spec = JobSpec::{
                , dirtyWhen =
                  [ S.strictlyStart (S.contains "src/app/hardfork_test")
                  , S.exactly "buildkite/src/Command/HardForkTest" "dhall"
                  , S.exactly ("buildkite/src/Jobs/Test/" ++ name) "dhall"
                  , S.exactly "scripts/hardfork/build-and-test" "sh"
                  , S.strictlyStart (S.contains "scripts/mina-local-network")
                  , S.strictlyStart (S.contains "nix")
                  , S.exactly "flake" "nix"
                  , S.exactly "flake" "lock"
                  , S.exactly "default" "nix"
                  ]
                , path = "Test"
                , name = name
                , scope = PipelineScope.AllButPullRequest
                , tags =
                  [ PipelineTag.Type.Long
                  , PipelineTag.Type.Test
                  , PipelineTag.Type.Stable
                  , PipelineTag.Type.Hardfork
                  ]
                }
              , steps =
                [ Command.build
                    Command.Config::{
                    , commands =
                      [ Cmd.runInDocker
                          Cmd.Docker::{
                          , image = ContainerImages.nixos
                          , privileged = True
                          , useBash = False
                          }
                          ("./scripts/hardfork/build-and-test.sh " ++ extraArgs)
                      ]
                    , label = label
                    , key = key
                    , target = Size.Integration
                    , soft_fail = Some (B/SoftFail.Boolean False)
                    , docker = None Docker.Type
                    , timeout_in_minutes = Some +420
                    }
                ]
              }
    }
