(* generate_keypair.ml -- utility app that only generates keypairs *)

open Core_kernel
open Async

let () =
  let is_version_cmd s =
    List.mem [ "version"; "-version" ] s ~equal:String.equal
  in
  match Sys.get_argv () with
  | [| _generate_keypair_exe; version |] when is_version_cmd version ->
      Mina_version.print_version ()
  | _ ->
      Command.run Cli_lib.Commands.generate_keypair
