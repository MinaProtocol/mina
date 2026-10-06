(* Sanity calls and a load run against a Rosetta endpoint that is already
   running. Both take their request arguments from that endpoint's archive. *)

open Async
open Rosetta_load

let () =
  Command.async_or_error
    ~summary:
      "Check a running Rosetta: one sanity call per endpoint, then an \
       open-loop load run with latency limits"
    (let%map_open.Command rosetta =
       flag "--rosetta-uri" (required string) ~doc:"URI Rosetta to test"
     and network =
       flag "--network" (required Network.arg_type) ~doc:"devnet|mainnet"
     and archive_uri =
       flag "--archive-uri" (required string)
         ~doc:"URI archive behind the Rosetta, for the request arguments"
     and load = Load.param
     and perf_output = Load.Perf_output.param in
     fun () ->
       let open Deferred.Or_error.Let_syntax in
       let client = Endpoint.client ~rosetta:(Uri.of_string rosetta) network in
       let%bind db = Sql.connect (Uri.of_string archive_uri) in
       let%bind () = Sanity.run ~client ~db in
       match load with
       | None ->
           return ()
       | Some config ->
           Load.run_and_report ~config ~client ~network ~db ~memory:Memory.none
             ~perf_output )
  |> Command_unix.run
