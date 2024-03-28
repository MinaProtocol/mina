let Prelude = ../External/Prelude.dhall
let B = ../External/Buildkite.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Cmd = ../Lib/Cmds.dhall in

{ step = \(dependsOn : List Command.TaggedKey.Type) 
    -> \(testnet : Text) 
    -> \(wait_between_graphql_poll : Text) 
    -> \(wait_before_final_check: Text )
    -> \(soft_fail: B/SoftFail)
    -> Command.build
        Command.Config::{
          commands = [
            Cmd.runInDocker
              Cmd.Docker::{
                image = (../Constants/ContainerImages.dhall).ubuntu2004
              }
              "./buildkite/scripts/connect-to-testnet.sh ${testnet} ${wait_between_graphql_poll} ${wait_before_final_check}"
          ],
          label = "Connect to ${testnet}",
          soft_fail = Some soft_fail,
          key = "connect-to-${testnet}",
          target = Size.Large,
          depends_on = dependsOn
        }
}
