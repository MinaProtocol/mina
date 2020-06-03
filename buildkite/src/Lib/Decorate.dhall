-- Decorate a comand step with echos to make it stand out

let Prelude = ../External/Prelude.dhall


let decorate = \(run : Text) ->
    [
      "echo \"--\"",
      "echo \"-- Running: ${run} --\"",
      "echo \"--\"",
      run
    ]

in

{
  decorate = decorate,
  decorateAll = \(commands : List Text) ->
    Prelude.List.concat Text
      (Prelude.List.map Text (List Text) decorate commands)
}

