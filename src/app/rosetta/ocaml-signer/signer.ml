open Async

let () =
  Command_unix.run
    ( Command.group ~summary:"OCaml reference signer implementation for Rosetta."
    @@ Signer_cli.commands () )
