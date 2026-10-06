(* Brings up what the mina-rosetta image used to run
   (src/app/rosetta/scripts/docker-start.sh): an archive database restored from
   the network's latest public dump, two rosetta instances, an archive node, a
   daemon that joins the network, and the missing-blocks guardian that fills the
   gap between the dump and the daemon's first block. Every service comes from
   [Mina_automation]. *)

open Core
open Async
open Mina_automation
module Network = Rosetta_load.Network
module Progress = Rosetta_load.Progress

module Config = struct
  type t =
    { network : Network.t
    ; repo_root : string
    ; workdir : string
    ; artifacts_dir : string
    ; postgres_uri : Uri.t
          (** an existing, empty database; the caller sets up the server *)
    ; archive_dump : [ `Latest | `None | `File of string ]
    ; backfill : bool
    ; graphql_port : int
    ; client_port : int
    ; archive_port : int
    ; rosetta_port : int
    ; rosetta_offline_port : int
    ; log_level : string
    }

  let genesis_config t =
    t.repo_root ^/ "genesis_ledgers" ^/ Network.to_string t.network ^ ".json"

  let seed_list t =
    sprintf "https://storage.googleapis.com/seed-lists/%s_seeds.txt"
      (Network.to_string t.network)

  let log t name = t.artifacts_dir ^/ name

  let graphql_uri t =
    Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port:t.graphql_port
      ~path:"/graphql" ()

  let connection t = Psql.Conn_str (Uri.to_string t.postgres_uri)
end

type service = { name : string; process : Process.t; log_file : string }

type t =
  { config : Config.t
  ; dirs : Daemon.Config.ConfigDirs.t
  ; mutable services : service list
  ; mutable daemon : Daemon.t option
  }

let services_named t ~prefix =
  List.filter t.services ~f:(fun s -> String.is_prefix s.name ~prefix)

(* Registers [process] as a service whose output goes to its own log file. *)
let add_service t ~name process =
  let log_file = Config.log t.config (name ^ ".log") in
  Progress.printf "started %s (pid %d, log: %s)" name
    (Pid.to_int (Process.pid process))
    log_file ;
  Utils.log_output_to_file process ~log_file ;
  t.services <- { name; process; log_file } :: t.services

let prepare_database (config : Config.t) =
  Archive_db.prepare ~postgres_uri:config.postgres_uri
    ~source:
      ( match config.archive_dump with
      | `None ->
          `Schema
      | `File file ->
          `Dump file
      | `Latest ->
          (* the newest dump of the last five days, as init-db.sh did *)
          `Latest_public_dump (Network.to_string config.network, 4) )
    ~workdir:config.workdir
    ~log_file:(Config.log config "dump-restore.log")

(* Every service runs until teardown, so one that has exited has failed. Checked
   for all of them, not just the daemon: rosetta exits at startup on a bad
   setting, and the sync wait would otherwise run out its whole timeout. *)
let exited_service t =
  List.find (List.rev t.services) ~f:(fun s -> not (Utils.is_running s.process))

let start_rosettas t =
  let config = t.config in
  Deferred.List.iter
    [ ("rosetta", config.rosetta_port)
    ; ("rosetta-offline", config.rosetta_offline_port)
    ]
    ~f:(fun (name, port) ->
      let%map rosetta =
        Rosetta.start
          (Rosetta.of_config
             (Rosetta.Config.create ~log_level:config.log_level
                ~archive_uri:config.postgres_uri
                ~graphql_uri:(Config.graphql_uri config)
                ~port () ) )
      in
      add_service t ~name rosetta.process )

let start_archive t =
  let config = t.config in
  let%map archive =
    Archive.start
      (Archive.of_config
         (Archive.Config.without_config_file ~log_level:config.log_level
            ~postgres_uri:(Uri.to_string config.postgres_uri)
            ~server_port:config.archive_port () ) )
  in
  add_service t ~name:"archive" archive.process

(* The seed list is fetched here rather than with --peer-list-url: the daemon's
   own HTTPS client has no retry, and one connect timeout to the bucket ends
   it. *)
let start_daemon t =
  let config = t.config in
  let open Deferred.Or_error.Let_syntax in
  let peers = config.workdir ^/ "peers.txt" in
  let%bind _ =
    Deferred.Or_error.try_with (fun () ->
        Utils.wget ~url:(Config.seed_list config) ~target:peers )
  in
  let daemon_config =
    Daemon.Config.of_dirs ~dirs:t.dirs ~client_port:config.client_port
      ~rest_port:config.graphql_port ()
  in
  let%bind () =
    Deferred.Or_error.try_with (fun () ->
        Daemon.Config.generate_keys daemon_config )
  in
  let daemon = Daemon.of_config daemon_config in
  let%map process =
    Deferred.ok
      (Daemon.start daemon ~seed:false ~demo_mode:false ~external_ip:None
         ~config_files:[ Config.genesis_config config ]
         ~peer_list_file:peers
         ~archive_address:(sprintf "127.0.0.1:%d" config.archive_port)
         ~log_level:config.log_level )
  in
  t.daemon <- Some daemon ;
  add_service t ~name:"daemon" process.process

let start_guardian t =
  let config = t.config in
  let%map process =
    Missing_blocks_guardian.run_in_background Missing_blocks_guardian.default
      ~config:
        { archive_uri = config.postgres_uri
        ; precomputed_blocks =
            Uri.of_string
              "https://storage.googleapis.com/mina_network_block_data"
        ; network = Network.to_string config.network
        ; run_mode = Daemon { interval = Time.Span.of_hr 1. }
        ; missing_blocks_auditor = "mina-missing-blocks-auditor"
        ; archive_blocks = "mina-archive-blocks"
        ; block_format = `Precomputed
        }
  in
  add_service t ~name:"guardian" process

let start_services t =
  let open Deferred.Or_error.Let_syntax in
  let%bind () = Deferred.ok (start_rosettas t) in
  let%bind () = Deferred.ok (start_archive t) in
  let%bind () = start_daemon t in
  let%bind () =
    if t.config.backfill then Deferred.ok (start_guardian t) else return ()
  in
  let%bind () = Deferred.ok (after (Time.Span.of_sec 30.)) in
  match exited_service t with
  | None ->
      return ()
  | Some s ->
      Deferred.Or_error.errorf "%s exited during startup, see %s" s.name
        s.log_file

let create (config : Config.t) =
  let%bind () = Unix.mkdir ~p:() config.workdir in
  let%map () = Unix.mkdir ~p:() config.artifacts_dir in
  { config
  ; dirs = Daemon.Config.ConfigDirs.create ~root_path:config.workdir ()
  ; services = []
  ; daemon = None
  }

let setup t =
  let%bind.Deferred.Or_error () = prepare_database t.config in
  start_services t

let rosetta_client t =
  Rosetta_load.Endpoint.client
    ~rosetta:
      (Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port:t.config.rosetta_port ())
    t.config.network

(* The daemon can call itself synced while it serves a best tip from hours ago;
   insist the tip is recent before trusting the rosetta sync status. The bash
   test used the same 4 h bound (80 slots at 3 min). *)
let best_tip_age config =
  match%map
    Mina_graphql_client.Client.get_best_chain ~max_length:1 ~num_tries:1
      ~logger:(Logger.null ())
      (Config.graphql_uri config)
  with
  | Ok (tip :: _) ->
      Some (Time.diff (Time.now ()) (Block_time.to_time_exn tip.timestamp))
  | Ok [] | Error _ ->
      None

let max_best_tip_age = Time.Span.of_hr 4.

let wait_for_sync t ~timeout =
  let client = rosetta_client t in
  let deadline = Time.add (Time.now ()) timeout in
  let rec loop () =
    match exited_service t with
    | Some s ->
        Deferred.Or_error.errorf "%s exited while syncing, see %s" s.name
          s.log_file
    | None ->
        let%bind { result; _ } =
          Rosetta_load.Endpoint.call client Network_status ~arg:""
        in
        let%bind synced =
          match result with
          | Error msg ->
              Progress.printf "sync: not yet (%s)" msg ;
              return false
          | Ok () -> (
              match%map best_tip_age t.config with
              | Some age when Time.Span.( < ) age max_best_tip_age ->
                  Progress.printf "sync: synced, best tip %s old"
                    (Time.Span.to_string_hum age) ;
                  true
              | Some age ->
                  Progress.printf
                    "sync: rosetta says synced but the best tip is %s old"
                    (Time.Span.to_string_hum age) ;
                  false
              | None ->
                  Progress.printf
                    "sync: rosetta says synced but the daemon has no best tip" ;
                  false )
        in
        if synced then Deferred.Or_error.return ()
        else if Time.( > ) (Time.now ()) deadline then
          Deferred.Or_error.errorf "not synced after %s"
            (Time.Span.to_string_hum timeout)
        else
          let%bind () = after (Time.Span.of_sec 30.) in
          loop ()
  in
  loop ()

(* RSS of the services under load: postgres summed over every visible process
   of that name (the server is not our child; in CI it is a container whose
   PID namespace the test shares), the others summed over their processes. *)
let memory t =
  let rss services () =
    List.sum
      (module Float)
      services
      ~f:(fun s ->
        Utils.get_memory_usage_mib (Pid.to_int (Process.pid s.process))
        |> Option.value ~default:0. )
    |> Option.some |> return
  in
  Rosetta_load.Memory.create
    [ ( "postgres"
      , fun () ->
          Utils.get_memory_usage_mib_of_user_process "postgres" >>| Option.some
      )
    ; ("archive", rss (services_named t ~prefix:"archive"))
    ; ("rosetta", rss (services_named t ~prefix:"rosetta"))
    ]

let collect_logs t =
  let config = t.config in
  let%bind status =
    match t.daemon with
    | None ->
        return "no daemon"
    | Some daemon ->
        Daemon.Client.status (Daemon.client daemon)
  in
  let%bind () =
    Writer.save (Config.log config "daemon-status.json") ~contents:status
  in
  (* Top-level logs only; the rest of the config dir is ledgers. *)
  let dest = Config.log config "mina-logs" in
  let%bind () = Unix.mkdir ~p:() dest in
  match%bind Monitor.try_with (fun () -> Sys.readdir t.dirs.conf) with
  | Error _ ->
      return ()
  | Ok files ->
      Deferred.Array.iter files ~f:(fun file ->
          if String.is_suffix file ~suffix:".log" then
            Process.run ~prog:"cp" ~args:[ t.dirs.conf ^/ file; dest ] ()
            |> Deferred.ignore_m
          else return () )

let teardown t =
  let%bind () =
    match
      (t.daemon, List.find t.services ~f:(fun s -> String.equal s.name "daemon"))
    with
    | Some daemon, Some service when Utils.is_running service.process ->
        let%bind () = Daemon.Client.stop_daemon (Daemon.client daemon) in
        Utils.terminate ~grace:(Time.Span.of_sec 30.) service.process
    | _ ->
        return ()
  in
  Deferred.List.iter t.services ~f:(fun s ->
      if Utils.is_running s.process then
        Progress.printf "stopping %s (pid %d)" s.name
          (Pid.to_int (Process.pid s.process)) ;
      Utils.terminate s.process )
