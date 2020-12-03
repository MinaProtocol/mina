-- Decorate a comand step with echos to make it stand out

let Prelude = ../External/Prelude.dhall

let Optional/fold_ = Prelude.Optional.fold

let Cmd = ./Cmds.dhall


let decorate : Cmd.Type -> List Text = \(run : Cmd.Type) ->
  Optional/fold_
    Text
    run.readable
    (List Text)
    (\(readable : Text) ->
      [
        "echo \"--\"",
        "echo \"-- Running: ${readable} --\"",
        "echo \"--\"",
        run.line
      ])
    [ run.line ]
in

{
  decorate = decorate,
  decorateAll = \(commands : List Cmd.Type) ->
    Prelude.List.concatMap
      Cmd.Type
      Text
      decorate
      commands
}

