open Core
open Async
open Mina_base
open Cli_lib
open Signature_lib

let plumb_modules_together () = 

let command =
  (* going to use --config-file, --transaction-trace *)
  Command.async
    ~summary:"Simulate a complete blockchain history from a summary."
    (let open Command.Let_syntax in
    let open Arg_type in
    let%map_open config_file = Flag.config_files
    and transaction_trace =
      flag "--transaction-trace" ~aliases:[ "transaction-trace" ]
        ~doc:"FILE Transaction trace file to replay" (optional string)
    in
    fun () -> Deferred.return ())
