open Async

let () =
  Command.run
    (Command.group
       ~summary:"OCaml reference signer implementation for Rosetta."
       Rosetta_signer.commands)
