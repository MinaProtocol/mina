let Pipeline =  ../../Pipeline/Dsl.dhall
let Cmd = ../../Lib/Cmds.dhall
let Command/Coda =  ../../Command/Coda.dhall 
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let commands =
  [ Cmd.run "eval $$(opam config  env)"
  , Cmd.run  "./scripts/compare_test_signatures.sh" ]
in

Pipeline.build
  Pipeline.Config::{
    spec = ./Spec.dhall,
    steps = [
      Command/Coda.build 
        Command/Coda.Config::{
           commands = commands,
           label = "Compare test signatures",
           key = "check"
        }
    ]
  }