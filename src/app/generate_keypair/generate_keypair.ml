open Async

(* Utiltity app that only generates keypairs *)
let () = Command.run Cli_lib.Generate_keypair.generate_keypair
