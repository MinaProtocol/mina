(* validate_keypair.ml *)

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
      Command.run Cli_lib.Commands.validate_keypair
