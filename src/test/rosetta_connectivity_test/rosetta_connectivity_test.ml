(* Rosetta connectivity, load and schema compatibility test against a live
   network. See [Harness] for what it starts. *)

open Core
open Async

let step name f =
  Proc.log "===== %s =====" name ;
  f () |> Deferred.Or_error.tag ~tag:name

let load_step ~load_config ~rosetta ~network ~db ~memory ~perf_output_file
    ~branch ~commit =
  step "load" (fun () ->
      let open Deferred.Or_error.Let_syntax in
      let%bind result =
        Load.run ~config:load_config ~rosetta ~network ~db ~memory
      in
      Load.print_report result ;
      let%bind () =
        Deferred.ok
          (Writer.save perf_output_file
             ~contents:(Load.influx_line result ~network ~branch ~commit ^ "\n") )
      in
      match result.failures with
      | [] ->
          return ()
      | failures ->
          Deferred.Or_error.error_string (String.concat ~sep:"\n" failures) )

(* Sanity and load against a rosetta someone else runs, e.g. a public
   endpoint; [postgres_uri] is its archive, for the load samples. *)
let run_external ~rosetta ~network ~postgres_uri ~load ~perf_output_file ~branch
    ~commit =
  let open Deferred.Or_error.Let_syntax in
  let%bind () = step "sanity" (fun () -> Sanity.run ~rosetta ~network) in
  match load with
  | None ->
      return ()
  | Some load_config ->
      let%bind db = Db.connect postgres_uri in
      load_step ~load_config ~rosetta ~network ~db
        ~memory:(Memory.create ~local_postgres:false ~services:[])
        ~perf_output_file ~branch ~commit

let run ~(harness : Harness.t) ~sync_timeout ~new_block_timeout ~load
    ~compatibility ~perf_output_file ~branch ~commit =
  let config = harness.config in
  let network = config.network in
  let rosetta = Harness.Config.rosetta_uri config.rosetta_port in
  let open Deferred.Or_error.Let_syntax in
  let%bind () = step "setup" (fun () -> Harness.setup harness) in
  let%bind () =
    step "sync" (fun () -> Harness.wait_for_sync harness ~timeout:sync_timeout)
  in
  let%bind () = step "sanity" (fun () -> Sanity.run ~rosetta ~network) in
  let%bind db = Db.connect config.postgres_uri in
  let%bind () =
    match load with
    | None ->
        return ()
    | Some load_config ->
        load_step ~load_config ~rosetta ~network ~db
          ~memory:
            (Memory.create ~local_postgres:true
               ~services:
                 [ ("archive", Harness.archive_services harness)
                 ; ("rosetta", Harness.rosetta_services harness)
                 ] )
          ~perf_output_file ~branch ~commit
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
         ~doc:"DIR mina checkout (genesis_ledgers, archive SQL)"
     and workdir =
       flag "--workdir"
         (optional_with_default "rosetta-connectivity" string)
         ~doc:"DIR daemon config dir, keypair, downloaded dump"
     and artifacts_dir =
       flag "--artifacts-dir"
         (optional_with_default "test_output/artifacts" string)
         ~doc:"DIR service logs and reports"
     and postgres_uri =
       flag "--postgres-uri"
         (optional_with_default
            "postgres://pguser:pguser@127.0.0.1:5432/archive" string )
         ~doc:"URI archive database; the user must be able to create it"
     and postgres_cluster_dir =
       flag "--create-postgres-cluster" (optional string)
         ~doc:
           "DIR replace the local 'main' cluster with a new one here (sudo), \
            and create the --postgres-uri user in it"
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
     and load_duration =
       flag "--load-duration"
         (optional_with_default 600 int)
         ~doc:"SECONDS 0 skips the load run"
     and rates =
       flag "--load-rates"
         (optional_with_default "" string)
         ~doc:
           "ENDPOINT=RPS,... override requests per second (defaults: \
            network_status=0.1,network_options=0.1,block=0.5,account_balance=1,payment_transaction=0.5,zkapp_transaction=1)"
     and p95_limits =
       flag "--p95-limits"
         (optional_with_default "" string)
         ~doc:"ENDPOINT=MS,... override p95 latency limits"
     and max_in_flight =
       flag "--max-in-flight"
         (optional_with_default 32 int)
         ~doc:"N requests outstanding at once"
     and compatibility =
       flag "--compatibility" no_arg ~doc:" run the schema script rounds"
     and perf_output_file =
       flag "--perf-output-file"
         (optional_with_default "rosetta.perf" string)
         ~doc:"FILE InfluxDB line for the bench database"
     and branch =
       flag "--branch" (optional_with_default "unknown" string) ~doc:"NAME"
     and commit =
       flag "--commit" (optional_with_default "unknown" string) ~doc:"SHA"
     and mina = flag "--mina" (optional_with_default "mina" string) ~doc:"PATH"
     and mina_archive =
       flag "--mina-archive"
         (optional_with_default "mina-archive" string)
         ~doc:"PATH"
     and mina_rosetta =
       flag "--mina-rosetta"
         (optional_with_default "mina-rosetta" string)
         ~doc:"PATH"
     and guardian =
       flag "--guardian"
         (optional_with_default "mina-missing-blocks-guardian" string)
         ~doc:"PATH"
     and graphql_port =
       flag "--graphql-port" (optional_with_default 3085 int) ~doc:"PORT"
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
     and external_rosetta =
       flag "--rosetta-uri" (optional string)
         ~doc:
           "URI test this rosetta instead of starting one: sanity and load \
            only, load samples from --postgres-uri"
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
         ; postgres_cluster_dir
         ; archive_dump
         ; backfill = not no_backfill
         ; graphql_port
         ; archive_port
         ; rosetta_port
         ; rosetta_offline_port
         ; mina
         ; mina_archive
         ; mina_rosetta
         ; guardian
         ; log_level
         }
       in
       let load =
         if load_duration = 0 then None
         else
           Some
             { Load.Config.duration = Time.Span.of_int_sec load_duration
             ; rates =
                 Load.Config.parse_overrides ~defaults:Load.Config.default_rates
                   rates
             ; p95_limits_ms =
                 Load.Config.parse_overrides
                   ~defaults:Load.Config.default_p95_limits_ms p95_limits
             ; max_in_flight
             ; sample_size = 100
             }
       in
       match external_rosetta with
       | Some uri ->
           run_external ~rosetta:(Uri.of_string uri) ~network
             ~postgres_uri:config.postgres_uri ~load ~perf_output_file ~branch
             ~commit
       | None ->
           let%bind harness = Harness.create config in
           (* An exception is a failed run too: it must still stop the services
              and keep their logs. *)
           let%bind result =
             Monitor.try_with ~extract_exn:true ~rest:`Log (fun () ->
                 run ~harness
                   ~sync_timeout:(Time.Span.of_int_sec sync_timeout)
                   ~new_block_timeout:(Time.Span.of_int_sec new_block_timeout)
                   ~load ~compatibility ~perf_output_file ~branch ~commit )
             >>| Result.map_error ~f:Error.of_exn
             >>| Or_error.join
           in
           let%bind () =
             match result with
             | Ok () ->
                 Proc.log "rosetta %s connectivity test passed"
                   (Network.to_string network) ;
                 return ()
             | Error _ ->
                 Harness.collect_logs harness
           in
           let%map () = Harness.teardown harness in
           result )
  |> Command.run
