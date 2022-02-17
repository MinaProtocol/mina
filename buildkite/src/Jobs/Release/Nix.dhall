let Prelude = ../../External/Prelude.dhall

let S = ../../Lib/SelectFiles.dhall

let Cmd = ../../Lib/Cmds.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let Nix = ../../Command/Nix.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.contains "src", S.strictlyStart (S.contains "nix") ]
        , path = "Release"
        , name = "Nix"
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands = Nix.nixBuild "mina"
            , label = "Build Mina with Nix"
            , key = "build-with-nix"
            , target = Size.Large
            , docker = None Docker.Type
            }
        ]
      }
