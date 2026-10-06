(* Rosetta connectivity, load and schema compatibility test against a live
   network. [Harness] starts the services; [Rosetta_load] checks them. *)

open Core
open Async
open Rosetta_load

let step name f =
  Progress.printf "===== %s =====" name ;
  f () |> Deferred.Or_error.tag ~tag:name

let run ~(harness : Harness.t) ~sync_timeout ~new_block_timeout ~load
    ~compatibility ~perf_output =
  let config = harness.config in
  let network = config.network in
  let client = Harness.rosetta_client harness in
  let open Deferred.Or_error.Let_syntax in
  let%bind () = step "setup" (fun () -> Harness.setup harness) in
  let%bind () =
    step "sync" (fun () -> Harness.wait_for_sync harness ~timeout:sync_timeout)
  in
  let%bind db = Sql.connect config.postgres_uri in
  let%bind () = step "sanity" (fun () -> Sanity.run ~client ~db) in
  let%bind () =
    match load with
    | None ->
        return ()
    | Some load_config ->
        step "load" (fun () ->
            Load.run_and_report ~config:load_config ~client ~network ~db
              ~memory:(Harness.memory harness) ~perf_output )
  in
  if compatibility then
    step "compatibility" (fun () -> Compat.run config ~db ~new_block_timeout)
  else return ()

let () =
  Command.async_or_error
    ~summary:
      "Join a network with a daemon, archive and rosetta, then check rosetta: \
       sanity calls, a load run with latency limits, and the archive schema \
       upgrade/downgrade scripts"
    (let%map_open.Command network =
       flag "--network" (required Network.arg_type) ~doc:"devnet|mainnet"
     and repo_root =
       flag "--repo-root"
         (optional_with_default "." string)
         ~doc:"DIR mina checkout (genesis_ledgers)"
     and workdir =
       flag "--workdir"
         (optional_with_default "rosetta-connectivity" string)
         ~doc:"DIR daemon config dirs, keypair, downloaded dump"
     and artifacts_dir =
       flag "--artifacts-dir"
         (optional_with_default "test_output/artifacts" string)
         ~doc:"DIR service logs and reports"
     and postgres_uri =
       flag "--postgres-uri"
         (optional_with_default
            "postgres://pguser:pguser@127.0.0.1:5432/archive" string )
         ~doc:
           "URI an existing, empty archive database (named archive for a \
            public dump)"
     and archive_dump =
       flag "--archive-dump"
         (optional_with_default "latest" string)
         ~doc:
           "latest|none|FILE seed the archive from the network's newest public \
            dump, start empty, or restore a local .sql"
     and no_backfill =
       flag "--no-backfill" no_arg
         ~doc:" do not run the missing-blocks guardian"
     and sync_timeout =
       flag "--sync-timeout" (optional_with_default 900 int) ~doc:"SECONDS"
     and new_block_timeout =
       flag "--new-block-timeout"
         (optional_with_default 600 int)
         ~doc:"SECONDS wait for a new archived block after each schema round"
     and load = Load.param
     and perf_output = Load.Perf_output.param
     and compatibility =
       flag "--compatibility" no_arg ~doc:" run the schema script rounds"
     and graphql_port =
       flag "--graphql-port" (optional_with_default 3085 int) ~doc:"PORT"
     and client_port =
       flag "--client-port" (optional_with_default 8301 int) ~doc:"PORT"
     and archive_port =
       flag "--archive-port" (optional_with_default 3086 int) ~doc:"PORT"
     and rosetta_port =
       flag "--rosetta-port" (optional_with_default 3087 int) ~doc:"PORT"
     and rosetta_offline_port =
       flag "--rosetta-offline-port"
         (optional_with_default 3088 int)
         ~doc:"PORT"
     and log_level =
       flag "--log-level" (optional_with_default "Info" string) ~doc:"LEVEL"
     in
     fun () ->
       let archive_dump =
         match archive_dump with
         | "latest" ->
             `Latest
         | "none" ->
             `None
         | file ->
             `File file
       in
       let config : Harness.Config.t =
         { network
         ; repo_root
         ; workdir
         ; artifacts_dir
         ; postgres_uri = Uri.of_string postgres_uri
         ; archive_dump
         ; backfill = not no_backfill
         ; graphql_port
         ; client_port
         ; archive_port
         ; rosetta_port
         ; rosetta_offline_port
         ; log_level
         }
       in
       let%bind harness = Harness.create config in
       (* An exception is a failed run too: it must still stop the services
          and keep their logs. *)
       let%bind result =
         Monitor.try_with ~extract_exn:true ~rest:`Log (fun () ->
             run ~harness
               ~sync_timeout:(Time.Span.of_int_sec sync_timeout)
               ~new_block_timeout:(Time.Span.of_int_sec new_block_timeout)
               ~load ~compatibility ~perf_output )
         >>| Result.map_error ~f:Error.of_exn
         >>| Or_error.join
       in
       let%bind () =
         match result with
         | Ok () ->
             Progress.printf "rosetta %s connectivity test passed"
               (Network.to_string network) ;
             return ()
         | Error _ ->
             Harness.collect_logs harness
       in
       let%map () = Harness.teardown harness in
       result )
  |> Command.run
