(**
Module to run daemon process.
*)
open Core

open Integration_test_lib
open Async

module Paths = struct
  let dune_name = "src/app/cli/src/mina.exe"

  let official_name = "mina"
end

module Executor = Executor.Make (Paths)

let logger = Logger.create ()

let path () =
  Deferred.map Executor.PathFinder.standalone_path ~f:(fun opt ->
      Option.value_exn opt
        ~message:
          "Could not find released mina daemon environment. App is not \
           executable outside the dune" )

let default_init_log_filters =
  [ Structured_log_events.string_of_id
      Transition_router
      .starting_transition_frontier_controller_structured_events_id
  ]

(** 
  Module [Client] provides functions to interact with a Mina daemon.
*)
module Client = struct
  type t = { port : int; executor : Executor.t }

  let create ?(port = 8031) ?(executor = Executor.AutoDetect) () =
    { port; executor }

  (** [stop_daemon t] stops the daemon running on the specified port.
    @param t The daemon instance containing the executor and port information.
    @return Unit. Executes the command to stop the daemon using the executor.
  *)
  let stop_daemon t : unit Deferred.t =
    let%map _ =
      Executor.run t.executor
        ~args:[ "client"; "stop-daemon"; "-daemon-port"; sprintf "%d" t.port ]
        ()
    in
    ()

  let ledger_hash t ~ledger_file =
    Executor.run t.executor
      ~args:[ "ledger"; "hash"; "--ledger-file"; ledger_file ]
      ()

  let ledger_currency t ~ledger_file =
    Executor.run t.executor
      ~args:[ "ledger"; "currency"; "--ledger-file"; ledger_file ]
      ()

  let ledger_export_snarked_ledger t =
    Executor.run t.executor
      ~args:
        [ "ledger"
        ; "export"
        ; "snarked-ledger"
        ; "--daemon-port"
        ; string_of_int t.port
        ]
      ()

  let test_ledger t ~(n : int) =
    Executor.run t.executor
      ~args:[ "ledger"; "test"; "generate-accounts"; "-n"; string_of_int n ]
      ()

  let advanced_print_signature_kind t =
    Executor.run t.executor ~args:[ "advanced"; "print-signature-kind" ] ()

  let advanced_compile_time_constants t ~config_file =
    Executor.run t.executor
      ~env:(`Extend [ ("MINA_CONFIG_FILE", config_file) ])
      ~args:[ "advanced"; "compile-time-constants" ]
      ()

  let advanced_constraint_system_digests t =
    Executor.run t.executor ~args:[ "advanced"; "constraint-system-digests" ] ()

  let advanced_runtime_config t ~rest_port =
    Executor.run t.executor
      ~args:
        [ "advanced"
        ; "runtime-config"
        ; "--rest-server"
        ; sprintf "http://localhost:%d/graphql" rest_port
        ]
      ()
end

module Config = struct
  module ConfigDirs = struct
    type t =
      { root_path : string
      ; conf : Filename.t
      ; genesis : Filename.t
      ; libp2p_keypair : Filename.t
      }

    let libp2p_keypair_folder t = String.concat [ t.libp2p_keypair; "/privkey" ]

    let create ?(root_path = "/tmp") ?(config_dir = "mina_spun_test")
        ?(genesis_dir = "mina_genesis_state")
        ?(p2p_dir = "mina_test_libp2p_keypair") () =
      Unix.putenv ~key:"MINA_LIBP2P_PASS" ~data:"naughty blue worm" ;
      Unix.putenv ~key:"MINA_PRIVKEY_PASS" ~data:"naughty blue worm" ;
      (* create empty config dir to avoid any issues with the default config dir *)
      let conf = Filename.temp_dir ~in_dir:root_path config_dir "" in
      let genesis = Filename.temp_dir ~in_dir:root_path genesis_dir "" in
      let libp2p_keypair = Filename.temp_dir ~in_dir:root_path p2p_dir "" in
      { root_path; conf; genesis; libp2p_keypair }

    let dirs t = [ t.conf; t.genesis; t.libp2p_keypair ]

    let default =
      let root = Filename.temp_dir ~in_dir:"/tmp" "mina_automation" "" in
      create ~root_path:root ()

    let mina_log t = t.conf ^/ "mina.log"
  end

  type t =
    { client_port : int
    ; rest_port : int
    ; dirs : ConfigDirs.t
    ; config : Test_config.t
    ; runtime_config : Runtime_config.t
    ; genesis_ledger : Genesis_ledger.t
    }

  let create ?(client_port = 8031) ?(rest_port = 3085) ~(dirs : ConfigDirs.t)
      ~(config : Test_config.t) () =
    let genesis_ledger = Genesis_ledger.create config.genesis_ledger in
    let runtime_config =
      Runtime_config_builder.create ~test_config:config ~genesis_ledger
    in

    Yojson.Safe.to_file
      (dirs.conf ^/ "daemon.json")
      (Runtime_config.to_yojson runtime_config) ;

    { client_port; rest_port; dirs; config; runtime_config; genesis_ledger }

  let default () =
    create ~dirs:ConfigDirs.default
      ~config:(Test_config.default ~constants:Test_config.default_constants)
      ()

  let libp2p_keypair_folder t = ConfigDirs.libp2p_keypair_folder t.dirs

  let generate_keys t =
    Init.Client.generate_libp2p_keypair_do (libp2p_keypair_folder t) ()
end

(** 
  Module [Process] provides functions to interact with a Mina daemon process.
*)
module Process = struct
  type t = { process : Process.t; config : Config.t; client : Client.t }

  (** [force_kill t] sends a kill signal to the process associated with [t] and waits for the process to terminate.
    @param t The daemon instance containing the process to be killed.
    @return A deferred result indicating the success or failure of the operation.
  *)
  let force_kill t = Utils.force_kill t.process
end

let expected_init_event_id =
  Structured_log_events.string_of_id
    Transition_router
    .starting_transition_frontier_controller_structured_events_id

let entry_has_event_id ~event_id entry =
  match Yojson.Safe.from_string entry with
  | json -> (
      match Yojson.Safe.Util.member "event_id" json with
      | `String id ->
          String.equal id event_id
      | _ ->
          false )
  | exception _ ->
      false

let wait_for_node_init ?(initial_delay_sec = 2.) ?(poll_interval_sec = 5.)
    ?(timeout_sec = 600.) (process : Process.t) =
  let node_uri =
    Uri.make ~scheme:"http" ~host:"localhost" ~port:process.config.rest_port
      ~path:"/graphql" ()
  in
  Async.printf "Waiting initial %.0f s. before polling GraphQL for node init\n"
    initial_delay_sec ;
  Mina_graphql_client.Client.poll_filtered_log_entries ~initial_delay_sec
    ~poll_interval_sec ~timeout_sec
    ~on_entries:(fun entries ->
      if
        Array.exists entries
          ~f:(entry_has_event_id ~event_id:expected_init_event_id)
      then (
        Async.printf "Node initialization detected via GraphQL\n" ;
        Deferred.return `Stop )
      else (
        if Array.length entries > 0 then
          Async.printf
            "Received %d log entries but none matched expected init event, \
             continuing...\n"
            (Array.length entries) ;
        Deferred.return `Continue ) )
    ~on_error:(fun e ->
      Async.printf "GraphQL not ready (%s), retrying...\n"
        (Error.to_string_hum e) ;
      Deferred.return `Continue )
    node_uri

let archive_blocks t ~archive_address ~format blocks =
  let format_arg =
    match format with
    | `Precomputed ->
        "--precomputed"
    | `Extensional ->
        "--extensional"
  in
  Executor.run t
    ~args:
      ( [ "advanced"
        ; "archive-blocks"
        ; "--archive-addres"
        ; string_of_int archive_address
        ; format_arg
        ]
      @ blocks )

type t = { config : Config.t; executor : Executor.t }

let archive_blocks_from_files t ~archive_address ~format ?(sleep = 5) blocks =
  Deferred.List.iter blocks ~f:(fun block ->
      let%bind _ = archive_blocks t ~archive_address ~format [ block ] () in
      after (Time.Span.of_sec (Float.of_int sleep)) )

let of_test_config test_config =
  { config =
      Config.create ~dirs:Config.ConfigDirs.default ~config:test_config ()
  ; executor = Executor.AutoDetect
  }

let of_config config = { config; executor = Executor.AutoDetect }

let default () = { config = Config.default (); executor = Executor.AutoDetect }

let client t = Client.create ~port:t.config.client_port ~executor:t.executor ()

let start ?hardfork_handling ?block_producer_key ?config_files ?env
    ?peer_list_url ?node_status_url ?node_error_url ?simplified_node_stats
    ?(start_filtered_logs = default_init_log_filters) t =
  let open Deferred.Let_syntax in
  let base_args =
    [ "daemon"
    ; "--seed"
    ; "--demo-mode"
    ; "--insecure-rest-server"
    ; "--working-dir"
    ; "."
    ; "--client-port"
    ; string_of_int t.config.client_port
    ; "--rest-port"
    ; string_of_int t.config.rest_port
    ; "--config-directory"
    ; t.config.dirs.conf
    ; "--genesis-ledger-dir"
    ; t.config.dirs.genesis
    ; "--external-ip"
    ; "0.0.0.0"
    ; "--libp2p-keypair"
    ; Config.libp2p_keypair_folder t.config
    ]
  in
  let opt_arg key value_opt =
    match value_opt with None -> [] | Some value -> [ key; value ]
  in
  let bool_flag key value_opt =
    match value_opt with
    | Some true ->
        [ key; "true" ]
    | Some false ->
        [ key; "false" ]
    | None ->
        []
  in
  let config_file_args =
    match config_files with
    | None ->
        []
    | Some files ->
        List.concat_map files ~f:(fun f -> [ "--config-file"; f ])
  in
  let start_filtered_log_args =
    List.concat_map start_filtered_logs ~f:(fun f ->
        [ "--start-filtered-logs"; f ] )
  in
  let args =
    base_args
    @ opt_arg "--hardfork-handling" hardfork_handling
    @ opt_arg "--block-producer-key" block_producer_key
    @ opt_arg "--node-status-url" node_status_url
    @ opt_arg "--node-error-url" node_error_url
    @ bool_flag "--simplified-node-stats" simplified_node_stats
    @ config_file_args
    @ opt_arg "--peer-list-url" peer_list_url
    @ start_filtered_log_args
  in
  [%log debug] "Starting daemon" ;

  let%bind _, process = Executor.run_in_background t.executor ~args ?env () in

  let mina_process : Process.t =
    { config = t.config
    ; process
    ; client = Client.create ~port:t.config.client_port ~executor:t.executor ()
    }
  in
  Deferred.return mina_process
