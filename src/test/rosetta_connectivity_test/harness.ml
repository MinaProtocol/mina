(* Brings up what the mina-rosetta image used to run
   (src/app/rosetta/scripts/docker-start.sh): an archive database restored from
   the network's latest public dump, two rosetta instances, an archive node, a
   daemon that joins the network, and the missing-blocks guardian that fills the
   gap between the dump and the daemon's first block. *)

open Core
open Async

module Config = struct
  type t =
    { network : Network.t
    ; repo_root : string
    ; workdir : string
    ; artifacts_dir : string
    ; postgres_uri : Uri.t
    ; postgres_cluster_dir : string option
          (** create a fresh local cluster here (needs sudo), as the image did *)
    ; archive_dump : [ `Latest | `None | `File of string ]
    ; backfill : bool
    ; graphql_port : int
    ; archive_port : int
    ; rosetta_port : int
    ; rosetta_offline_port : int
    ; mina : string
    ; mina_archive : string
    ; mina_rosetta : string
    ; guardian : string
    ; log_level : string
    }

  let genesis_config t =
    t.repo_root ^/ "genesis_ledgers" ^/ Network.to_string t.network ^ ".json"

  let seed_list t =
    sprintf "https://storage.googleapis.com/seed-lists/%s_seeds.txt"
      (Network.to_string t.network)

  let config_dir t = t.workdir ^/ "mina-config"

  let keypair t = t.workdir ^/ "libp2p" ^/ "keypair"

  let log t name = t.artifacts_dir ^/ name

  let rosetta_uri port = Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port ()

  let graphql_uri t =
    Uri.make ~scheme:"http" ~host:"127.0.0.1" ~port:t.graphql_port
      ~path:"/graphql" ()

  let db_name t =
    String.chop_prefix_if_exists (Uri.path t.postgres_uri) ~prefix:"/"

  let admin_uri t = Uri.with_path t.postgres_uri "/postgres"
end

type t =
  { config : Config.t
  ; mutable services : Proc.service list
  ; mutable daemon : Proc.service option
  }

let rosetta_services t =
  List.filter t.services ~f:(fun s -> String.is_prefix s.name ~prefix:"rosetta")

let archive_services t =
  List.filter t.services ~f:(fun s -> String.equal s.name "archive")

let psql ?log_file uri args =
  let args = Uri.to_string uri :: args in
  match log_file with
  | Some log_file ->
      Proc.run_logged ~log_file "psql" args
  | None ->
      Proc.run "psql" args |> Deferred.Or_error.ignore_m

let sudo = Proc.run "sudo"

(* The toolchain image runs as a user with passwordless sudo and ships a
   postgres "main" cluster that is not ours to reuse. *)
let create_cluster (config : Config.t) ~dir =
  let open Deferred.Or_error.Let_syntax in
  let%bind version = Proc.run "psql" [ "-V" ] in
  let version =
    (* "psql (PostgreSQL) 15.4 (Debian 15.4-1)" -> "15" *)
    List.nth_exn (String.split (String.strip version) ~on:' ') 2
    |> String.split ~on:'.' |> List.hd_exn
  in
  let user = Option.value_exn (Uri.user config.postgres_uri) in
  let password = Option.value_exn (Uri.password config.postgres_uri) in
  (* absent on a fresh image; not an error *)
  let%bind () =
    Deferred.map
      (sudo [ "pg_dropcluster"; "--stop"; version; "main" ])
      ~f:(fun _ -> Ok ())
  in
  let%bind _ = sudo [ "mkdir"; "-p"; dir ] in
  let%bind _ = sudo [ "chown"; "postgres:postgres"; dir ] in
  let%bind _ =
    sudo
      [ "pg_createcluster"
      ; "--start"
      ; "-d"
      ; dir
      ; "--createclusterconf"
      ; config.repo_root ^/ "src/app/rosetta/scripts/postgresql.conf"
      ; version
      ; "main"
      ]
  in
  let%map _ =
    sudo
      [ "-u"
      ; "postgres"
      ; "psql"
      ; "--command"
      ; sprintf "CREATE USER %s WITH SUPERUSER PASSWORD '%s';" user password
      ]
  in
  ()

let dump_url network date =
  sprintf
    "https://storage.googleapis.com/mina-archive-dumps/%s-archive-dump-%s_0000.sql.tar.gz"
    (Network.to_string network)
    date

(* Newest dump of the last five days, as init-db.sh looked for. *)
let find_latest_dump network =
  let today = Date.today ~zone:Time.Zone.utc in
  Deferred.List.find_map (List.range 0 5) ~f:(fun days_back ->
      let date = Date.add_days today (-days_back) |> Date.to_string in
      let url = dump_url network date in
      match%map
        Monitor.try_with ~rest:`Log (fun () ->
            Cohttp_async.Client.head (Uri.of_string url) )
      with
      | Ok response
        when Cohttp.Code.is_success
               (Cohttp.Code.code_of_status (Cohttp.Response.status response)) ->
          Some (url, date)
      | _ ->
          None )

let restore_dump (config : Config.t) ~file =
  (* A pg_dump restore reports ownership and extension statements it cannot
     replay as errors and carries on, as init-db.sh let it. *)
  psql config.postgres_uri [ "-q"; "-f"; file ]
    ~log_file:(Config.log config "dump-restore.log")

let prepare_database (config : Config.t) =
  let open Deferred.Or_error.Let_syntax in
  let%bind () =
    match config.postgres_cluster_dir with
    | Some dir ->
        create_cluster config ~dir
    | None ->
        return ()
  in
  let db = Config.db_name config in
  let admin = Config.admin_uri config in
  let%bind () = psql admin [ "-c"; sprintf "DROP DATABASE IF EXISTS %s" db ] in
  let%bind () = psql admin [ "-c"; sprintf "CREATE DATABASE %s" db ] in
  let dump_file =
    match config.archive_dump with
    | `None ->
        return None
    | `File file ->
        return (Some file)
    | `Latest -> (
        match%bind Deferred.ok (find_latest_dump config.network) with
        | None ->
            Deferred.Or_error.errorf "no %s archive dump in the last 5 days"
              (Network.to_string config.network)
        | Some (url, date) ->
            let archive = config.workdir ^/ "archive-dump.tar.gz" in
            let%bind _ =
              Proc.run "curl" [ "-fsSL"; "--retry"; "3"; "-o"; archive; url ]
            in
            let%bind _ =
              Proc.run "tar" [ "-xzf"; archive; "-C"; config.workdir ]
            in
            let%map () = Deferred.ok (Unix.unlink archive) in
            Some
              ( config.workdir
              ^/ sprintf "%s-archive-dump-%s_0000.sql"
                   (Network.to_string config.network)
                   date ) )
  in
  match%bind dump_file with
  | None ->
      psql config.postgres_uri
        [ "-q"; "-f"; config.repo_root ^/ "src/app/archive/create_schema.sql" ]
  | Some file -> (
      let%bind () = restore_dump config ~file in
      (* a downloaded dump is several GB once extracted; a given one is not
         ours to delete *)
      match config.archive_dump with
      | `Latest ->
          Deferred.ok (Unix.unlink file)
      | `None | `File _ ->
          return () )

let start_services t =
  let config = t.config in
  let pg = Uri.to_string config.postgres_uri in
  let spawn ?env name prog args =
    let%map service =
      Proc.spawn ?env ~name
        ~log_file:(Config.log config (name ^ ".log"))
        prog args
    in
    t.services <- service :: t.services ;
    service
  in
  let%bind () =
    Deferred.List.iter
      [ ("rosetta", config.rosetta_port)
      ; ("rosetta-offline", config.rosetta_offline_port)
      ]
      ~f:(fun (name, port) ->
        (* docker-start.sh's value; rosetta refuses to start without one *)
        spawn name config.mina_rosetta
          ~env:(`Extend [ ("MINA_ROSETTA_MAX_DB_POOL_SIZE", "80") ])
          [ "--archive-uri"
          ; pg
          ; "--graphql-uri"
          ; Uri.to_string (Config.graphql_uri config)
          ; "--log-level"
          ; config.log_level
          ; "--port"
          ; Int.to_string port
          ]
        |> Deferred.ignore_m )
  in
  let%bind _ =
    spawn "archive" config.mina_archive
      [ "run"
      ; "--postgres-uri"
      ; pg
      ; "--log-level"
      ; config.log_level
      ; "--server-port"
      ; Int.to_string config.archive_port
      ]
  in
  (* The daemon refuses a keypair whose directory others can read. *)
  let%bind () =
    Unix.mkdir ~p:() ~perm:0o700 (Filename.dirname (Config.keypair config))
  in
  let env = `Extend [ ("MINA_LIBP2P_PASS", "") ] in
  (* Fetched here rather than with --peer-list-url: the daemon's own HTTPS
     client has no retry, and one connect timeout to the bucket ends it. *)
  let peers = config.workdir ^/ "peers.txt" in
  let%bind.Deferred.Or_error _ =
    Proc.run "curl"
      [ "-fsSL"; "--retry"; "5"; "-o"; peers; Config.seed_list config ]
  in
  let%bind.Deferred.Or_error _ =
    Proc.run ~env config.mina
      [ "libp2p"; "generate-keypair"; "-privkey-path"; Config.keypair config ]
  in
  let%bind daemon =
    spawn ~env "daemon" config.mina
      [ "daemon"
      ; "--config-file"
      ; Config.genesis_config config
      ; "--config-dir"
      ; Config.config_dir config
      ; "--libp2p-keypair"
      ; Config.keypair config
      ; "--peer-list-file"
      ; peers
      ; "--rest-port"
      ; Int.to_string config.graphql_port
      ; "-archive-address"
      ; sprintf "127.0.0.1:%d" config.archive_port
      ; "-insecure-rest-server"
      ; "--log-level"
      ; config.log_level
      ]
  in
  t.daemon <- Some daemon ;
  let%bind () =
    if not config.backfill then return ()
    else
      let uri = config.postgres_uri in
      spawn "guardian" config.guardian [ "daemon" ]
        ~env:
          (`Extend
            [ ("MINA_NETWORK", Network.to_string config.network)
            ; ( "PRECOMPUTED_BLOCKS_URL"
              , "https://storage.googleapis.com/mina_network_block_data" )
            ; ("DB_USERNAME", Option.value_exn (Uri.user uri))
            ; ("PGPASSWORD", Option.value_exn (Uri.password uri))
            ; ("DB_HOST", Option.value (Uri.host uri) ~default:"127.0.0.1")
            ; ( "DB_PORT"
              , Int.to_string (Option.value (Uri.port uri) ~default:5432) )
            ; ("DB_NAME", Config.db_name config)
            ; ("TIMEOUT", "3600")
            ] )
      |> Deferred.ignore_m
  in
  let%bind () = after (Time.Span.of_sec 30.) in
  if Proc.is_running daemon then Deferred.Or_error.return ()
  else
    Deferred.Or_error.errorf "daemon exited during startup, see %s"
      daemon.log_file

let create config =
  let%bind () = Unix.mkdir ~p:() config.Config.workdir in
  let%map () = Unix.mkdir ~p:() config.artifacts_dir in
  { config; services = []; daemon = None }

let setup t =
  let%bind.Deferred.Or_error () = prepare_database t.config in
  start_services t

(* The daemon can call itself synced while it serves a best tip from hours ago;
   insist the tip is recent before trusting the rosetta sync status. The bash
   test used the same 4 h bound (80 slots at 3 min). *)
let best_tip_age config =
  let query =
    `Assoc
      [ ( "query"
        , `String
            "{ bestChain(maxLength: 1) { protocolState { blockchainState { \
             utcDate } } } }" )
      ]
  in
  match%map Client.post (Config.graphql_uri config) query with
  | Error _ ->
      None
  | Ok { body; _ } -> (
      match
        Option.bind body ~f:(fun json ->
            Client.string_at json
              [ "data"
              ; "bestChain"
              ; "0"
              ; "protocolState"
              ; "blockchainState"
              ; "utcDate"
              ] )
      with
      | Some ms ->
          Some
            (Time.diff (Time.now ())
               (Time.of_span_since_epoch (Time.Span.of_ms (Float.of_string ms))) )
      | None ->
          None )

let max_best_tip_age = Time.Span.of_hr 4.

let wait_for_sync t ~timeout =
  let config = t.config in
  let rosetta = Config.rosetta_uri config.rosetta_port in
  let deadline = Time.add (Time.now ()) timeout in
  let rec loop () =
    let daemon_alive =
      Option.value_map t.daemon ~default:false ~f:Proc.is_running
    in
    if not daemon_alive then
      Deferred.Or_error.error_string "daemon exited while syncing"
    else
      let%bind { result; _ } =
        Endpoint.call ~rosetta ~network:config.network Network_status ~arg:""
      in
      let%bind synced =
        match result with
        | Error msg ->
            Proc.log "sync: not yet (%s)" msg ;
            return false
        | Ok () -> (
            match%map best_tip_age config with
            | Some age when Time.Span.( < ) age max_best_tip_age ->
                Proc.log "sync: synced, best tip %s old"
                  (Time.Span.to_string_hum age) ;
                true
            | Some age ->
                Proc.log "sync: rosetta says synced but the best tip is %s old"
                  (Time.Span.to_string_hum age) ;
                false
            | None ->
                Proc.log
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

let collect_logs t =
  let config = t.config in
  let%bind status = Proc.run config.mina [ "client"; "status"; "--json" ] in
  let%bind () =
    Writer.save
      (Config.log config "daemon-status.json")
      ~contents:
        (Result.ok status |> Option.value ~default:"could not get daemon status")
  in
  (* Top-level logs only; the rest of the config dir is ledgers. *)
  let dest = Config.log config "mina-logs" in
  let%bind () = Unix.mkdir ~p:() dest in
  match%bind
    Monitor.try_with (fun () -> Sys.readdir (Config.config_dir config))
  with
  | Error _ ->
      return ()
  | Ok files ->
      Deferred.Array.iter files ~f:(fun file ->
          if String.is_suffix file ~suffix:".log" then
            Proc.run "cp" [ Config.config_dir config ^/ file; dest ]
            |> Deferred.ignore_m
          else return () )

let teardown t =
  let%bind () =
    match t.daemon with
    | Some daemon when Proc.is_running daemon ->
        let%bind _ = Proc.run t.config.mina [ "client"; "stop-daemon" ] in
        Proc.stop ~grace:(Time.Span.of_sec 30.) daemon
    | _ ->
        return ()
  in
  Deferred.List.iter t.services ~f:(fun s -> Proc.stop s)
