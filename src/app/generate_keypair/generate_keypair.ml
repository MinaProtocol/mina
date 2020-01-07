open Async

(* Utiltity app that only generates keypairs *)
let () = Command.run Cli_lib.Commands.generate_keypair
