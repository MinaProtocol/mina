open Core_kernel
open Async

let () =
  (* intercept command-line processing for "version", because we don't
     use the Jane Street scripts that generate their version information
  *)
  let is_version_cmd s =
    List.mem [ "version"; "-version"; "--version" ] s ~equal:String.equal
  in
  match Async_unix.Sys.get_argv () with
  | [| _archive_exe; version |] when is_version_cmd version ->
      Mina_version.print_version ()
  | _ ->
      Command.run
        (Command.group ~summary:"Archive node commands" Archive_cli.commands)
