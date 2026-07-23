open Core
open Async
open Integration_test_lib

module Node = struct
  type config =
    { network_keypair : Network_keypair.t option
    ; service_name : string
    ; postgres_connection_uri : string option
    ; graphql_port : int
    ; ports : Native_node_config.Node_ports.t
    ; config_dir : string
    ; libp2p_key_path : string
    ; runtime_config_path : string option
    ; node_type : node_type
    ; cmd_args : string list
    ; mina_binary : string
    }

  and node_type =
    | Seed
    | Block_producer
    | Snark_coordinator
    | Snark_worker
    | Archive

  type t =
    { config : config
    ; mutable should_be_running : bool
    ; mutable process : Process.t option
    ; log_file : string
    }

  (* Size of the buffer used to stream a node's log file to a destination in
     [tail_mina_logs_to_file]. *)
  let log_follow_buffer_size = 4096

  let id { config; _ } = config.service_name

  let infra_id { config; _ } = config.service_name

  let should_be_running { should_be_running; _ } = should_be_running

  let network_keypair { config; _ } = config.network_keypair

  let get_ingress_uri node =
    Uri.make ~scheme:"http" ~host:"127.0.0.1" ~path:"/graphql"
      ~port:node.config.graphql_port ()

  let dump_archive_data ~logger (t : t) ~data_file =
    let service_name = t.config.service_name in
    match t.config.postgres_connection_uri with
    | None ->
        failwith
          (sprintf "dump_archive_data: %s not an archive container" service_name)
    | Some postgres_uri ->
        Local_engine_common.Ops.dump_archive_data
          ~run:(fun ~prog ~args -> Util.run_cmd_or_hard_error "/" prog args)
          ~logger ~service_name ~postgres_uri ~data_file

  let dump_mina_logs ~logger (t : t) ~log_file:dest_file =
    let open Malleable_error.Let_syntax in
    [%log info] "Dumping mina logs from (node: %s) to file %s"
      t.config.service_name dest_file ;
    let%bind.Deferred contents =
      match%map.Deferred
        Monitor.try_with ~here:[%here] (fun () ->
            Reader.file_contents t.log_file )
      with
      | Ok c ->
          c
      | Error _ ->
          ""
    in
    Out_channel.with_file dest_file ~f:(fun out_ch ->
        Out_channel.output_string out_ch contents ) ;
    return ()

  let tail_mina_logs_to_file ~logger (t : t) ~log_file =
    [%log info] "Streaming logs from (node: %s) to file %s"
      t.config.service_name log_file ;
    (* [start] already captures the node's stdout/stderr to [t.log_file]. Mirror
       that file into [log_file] as it grows, in-process, rather than spawning
       an external [tail -F]: when we hit EOF but the node is still running, we
       wait briefly and read again (following appends). [Monitor.protect]
       guarantees the reader and writer are closed on every exit path, so no
       file descriptor or writer is left dangling if the transfer raises. *)
    let poll = Time.Span.of_ms 200. in
    don't_wait_for
      ( match%map.Deferred
          Monitor.try_with ~here:[%here] (fun () ->
              (* Wait for the node to create its log file before following it. *)
              let%bind.Deferred () =
                Deferred.repeat_until_finished () (fun () ->
                    match%bind.Deferred Sys.file_exists t.log_file with
                    | `Yes ->
                        Deferred.return (`Finished ())
                    | _ ->
                        if t.should_be_running then
                          let%map.Deferred () = Clock.after poll in
                          `Repeat ()
                        else Deferred.return (`Finished ()) )
              in
              let%bind.Deferred dst = Writer.open_file log_file in
              Monitor.protect ~here:[%here]
                ~finally:(fun () -> Writer.close dst)
                (fun () ->
                  let%bind.Deferred src = Reader.open_file t.log_file in
                  Monitor.protect ~here:[%here]
                    ~finally:(fun () -> Reader.close src)
                    (fun () ->
                      let buf = Bytes.create log_follow_buffer_size in
                      Deferred.repeat_until_finished () (fun () ->
                          match%bind.Deferred Reader.read src buf with
                          | `Ok len ->
                              Writer.write_bytes dst buf ~len ;
                              let%map.Deferred () = Writer.flushed dst in
                              `Repeat ()
                          | `Eof ->
                              if t.should_be_running then
                                let%map.Deferred () = Clock.after poll in
                                `Repeat ()
                              else Deferred.return (`Finished ()) ) ) ) )
        with
      | Ok () ->
          ()
      | Error exn ->
          [%log warn] "Log streaming for node %s stopped: %s"
            t.config.service_name (Exn.to_string exn) ) ;
    Malleable_error.return ()

  let run_replayer ?(start_slot_since_genesis = 0) ?target_state_hash ~logger
      (t : t) =
    let runtime_config_path =
      Option.value_exn t.config.runtime_config_path
        ~message:"replayer requires runtime config path"
    in
    let postgres_uri = Option.value_exn t.config.postgres_connection_uri in
    Local_engine_common.Ops.run_replayer
      ~run:(fun ~prog ~args -> Util.run_cmd_or_hard_error "/" prog args)
      ~write_file:(fun ~contents ~dest ->
        Out_channel.with_file dest ~f:(fun ch ->
            Out_channel.output_string ch contents ) ;
        Malleable_error.return () )
      ~logger ~service_name:t.config.service_name ~runtime_config_path
      ~replayer_input_dest:(t.config.config_dir ^/ "replayer-input.json")
      ~postgres_uri ~start_slot_since_genesis ?target_state_hash ()

  let dump_precomputed_blocks ~logger (t : t) =
    [%log info] "Dumping precomputed blocks from logs for (node: %s)"
      t.config.service_name ;
    let%bind.Deferred logs =
      match%map.Deferred
        Monitor.try_with ~here:[%here] (fun () ->
            Reader.file_contents t.log_file )
      with
      | Ok c ->
          c
      | Error exn ->
          [%log warn]
            "Could not read log file %s for (node: %s) when dumping \
             precomputed blocks: %s"
            t.log_file t.config.service_name (Exn.to_string exn) ;
          ""
    in
    let log_lines =
      String.split logs ~on:'\n'
      |> List.filter ~f:(String.is_prefix ~prefix:"{\"timestamp\":")
    in
    let jsons = List.map log_lines ~f:Yojson.Safe.from_string in
    let metadata_jsons =
      List.map jsons ~f:(fun json ->
          match Yojson.Safe.Util.member "metadata" json with
          | `Null ->
              failwithf "Log line is missing metadata: %s"
                (Yojson.Safe.to_string json)
                ()
          | md ->
              md )
    in
    let state_hash_and_blocks =
      List.fold metadata_jsons ~init:[] ~f:(fun acc json ->
          match Yojson.Safe.Util.member "precomputed_block" json with
          | `Null ->
              acc
          | block -> (
              match Yojson.Safe.Util.member "state_hash" json with
              | `Null ->
                  failwith
                    "Log metadata contains a precomputed block, but no state \
                     hash"
              | state_hash ->
                  (state_hash, block) :: acc ) )
    in
    let%bind.Deferred () =
      Deferred.List.iter state_hash_and_blocks
        ~f:(fun (state_hash_json, block_json) ->
          let state_hash = Yojson.Safe.Util.to_string state_hash_json in
          let block = Yojson.Safe.pretty_to_string block_json in
          let filename = state_hash ^ ".json" in
          match%map.Deferred Sys.file_exists filename with
          | `Yes ->
              [%log info]
                "File already exists for precomputed block with state hash %s"
                state_hash
          | _ ->
              [%log info]
                "Dumping precomputed block with state hash %s to file %s"
                state_hash filename ;
              Out_channel.with_file filename ~f:(fun out_ch ->
                  Out_channel.output_string out_ch block ) )
    in
    Malleable_error.return ()

  (* Archive-node Postgres provisioning. The Postgres server itself is provided
     by the environment (a real server on CI); here we only create the
     per-test database and load the archive schema into it, mirroring the
     docker engine's postgres init entrypoint. *)

  let postgres_db_name uri =
    Uri.path (Uri.of_string uri) |> String.chop_prefix_if_exists ~prefix:"/"

  (* Administrative connection to the same server but the default [postgres]
     maintenance database, used to CREATE/DROP the per-test database. *)
  let postgres_admin_uri uri =
    Uri.with_path (Uri.of_string uri) "/postgres" |> Uri.to_string

  (* Locate the archive schema. Prefer the copy shipped by the mina-archive
     debian package (present on CI); fall back to the in-repo copy for local
     runs. *)
  let archive_schema_file () =
    let candidates =
      [ "/etc/mina/archive/create_schema.sql"
      ; "src/app/archive/create_schema.sql"
      ]
    in
    Deferred.List.find candidates ~f:(fun path ->
        match%map Sys.file_exists path with `Yes -> true | _ -> false )

  let provision_archive_db ~logger uri =
    let open Malleable_error.Let_syntax in
    let db_name = postgres_db_name uri in
    let admin_uri = postgres_admin_uri uri in
    [%log info] "Creating archive database %s" db_name ;
    let%bind _ =
      Util.run_cmd_or_hard_error "/" "psql"
        [ admin_uri
        ; "-v"
        ; "ON_ERROR_STOP=1"
        ; "-c"
        ; sprintf {|DROP DATABASE IF EXISTS "%s";|} db_name
        ; "-c"
        ; sprintf {|CREATE DATABASE "%s";|} db_name
        ]
    in
    let%bind schema =
      match%bind.Deferred archive_schema_file () with
      | Some schema ->
          Malleable_error.return schema
      | None ->
          Malleable_error.hard_error_string
            "could not locate create_schema.sql to initialise the archive \
             database"
    in
    [%log info] "Loading archive schema %s into database %s" schema db_name ;
    let%map _ =
      Util.run_cmd_or_hard_error "/" "psql"
        [ uri; "-v"; "ON_ERROR_STOP=1"; "-f"; schema ]
    in
    ()

  let drop_archive_db ~logger uri =
    let db_name = postgres_db_name uri in
    let admin_uri = postgres_admin_uri uri in
    [%log info] "Dropping archive database %s" db_name ;
    match%map.Deferred
      Monitor.try_with ~here:[%here] (fun () ->
          Util.run_cmd_exn "/" "psql"
            [ admin_uri
            ; "-c"
            ; sprintf {|DROP DATABASE IF EXISTS "%s";|} db_name
            ] )
    with
    | Ok _ ->
        ()
    | Error _ ->
        [%log warn] "Failed to drop archive database %s" db_name

  let recreate_config_dir ~logger ~fresh_state config_dir =
    let%bind.Deferred () =
      if fresh_state then
        match%map.Deferred
          Monitor.try_with ~here:[%here] (fun () ->
              Mina_stdlib_unix.File_system.remove_dir config_dir )
        with
        | Ok () ->
            ()
        | Error exn ->
            [%log warn] "Could not remove config directory %s: %s" config_dir
              (Exn.to_string exn)
      else Deferred.unit
    in
    Unix.mkdir ~p:() config_dir

  let start ~fresh_state (node : t) : unit Malleable_error.t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    [%log info] "Starting node %s" node.config.service_name ;
    node.should_be_running <- true ;
    let config_dir = node.config.config_dir ^/ ".mina-config" in
    let%bind.Deferred () =
      recreate_config_dir ~logger ~fresh_state config_dir
    in
    (* The "magic" config file is owned by the user and may live in a location
       requiring elevated privileges; warn rather than attempt to remove it. *)
    let commit_id = Mina_version.commit_id_short in
    let magic_config = config_dir ^/ sprintf "config_%s.json" commit_id in
    let%bind.Deferred () =
      match%map.Deferred Sys.file_exists magic_config with
      | `Yes ->
          [%log warn]
            "Config file %s already exists; please remove it before running"
            magic_config
      | _ ->
          ()
    in
    (* Generate libp2p keypair for non-seed nodes *)
    let%bind () =
      match node.config.node_type with
      | Seed | Archive ->
          (* Seed nodes use the hardcoded libp2p key; archive nodes run
             [mina-archive], which has no libp2p identity at all. *)
          Malleable_error.return ()
      | _ -> (
          (* Non-seed nodes need their own libp2p key generated *)
          let libp2p_key_path = node.config.libp2p_key_path in
          match%bind.Deferred Sys.file_exists libp2p_key_path with
          | `Yes ->
              [%log info] "libp2p key already exists at %s" libp2p_key_path ;
              Malleable_error.return ()
          | _ ->
              [%log info] "Generating libp2p keypair at %s" libp2p_key_path ;
              let env = `Extend Native_node_config.Base_node_config.env_vars in
              let%map _output =
                Util.run_cmd_or_hard_error ~env node.config.config_dir
                  node.config.mina_binary
                  [ "libp2p"
                  ; "generate-keypair"
                  ; "--privkey-path"
                  ; libp2p_key_path
                  ]
              in
              () )
    in
    (* Import account keys for block producer nodes *)
    let%bind () =
      match (node.config.node_type, node.config.network_keypair) with
      | Block_producer, Some _kp -> (
          (* Find the block producer key path from cmd_args *)
          let rec find_key_path = function
            | "-block-producer-key" :: path :: _ ->
                Some path
            | _ :: rest ->
                find_key_path rest
            | [] ->
                None
          in
          match find_key_path node.config.cmd_args with
          | Some key_path ->
              [%log info] "Importing account key %s for node %s" key_path
                node.config.service_name ;
              let config_dir_arg = node.config.config_dir ^/ ".mina-config" in
              let env = `Extend Native_node_config.Base_node_config.env_vars in
              let%map _output =
                Util.run_cmd_or_hard_error ~env node.config.config_dir
                  node.config.mina_binary
                  [ "accounts"
                  ; "import"
                  ; "--config-directory"
                  ; config_dir_arg
                  ; "--privkey-path"
                  ; key_path
                  ]
              in
              ()
          | None ->
              Malleable_error.return () )
      | _ ->
          Malleable_error.return ()
    in
    (* Archive nodes need their per-test database created and the archive
       schema loaded before [mina-archive] connects to it. *)
    let%bind () =
      match (node.config.node_type, node.config.postgres_connection_uri) with
      | Archive, Some uri ->
          provision_archive_db ~logger uri
      | _ ->
          Malleable_error.return ()
    in
    let env = `Extend Native_node_config.Base_node_config.env_vars in
    let%bind.Deferred process =
      Process.create_exn ~working_dir:node.config.config_dir
        ~prog:node.config.mina_binary ~args:node.config.cmd_args ~env ()
    in
    node.process <- Some process ;
    (* Redirect stdout and stderr to log file *)
    don't_wait_for
      (let%bind.Deferred writer = Writer.open_file node.log_file in
       let pipe_w = Writer.pipe writer in
       let%bind.Deferred () =
         Deferred.all_unit
           [ Reader.transfer (Process.stdout process) pipe_w
           ; Reader.transfer (Process.stderr process) pipe_w
           ]
       in
       Writer.close writer ) ;
    return ()

  let stop (node : t) =
    let open Malleable_error.Let_syntax in
    node.should_be_running <- false ;
    let%bind.Deferred () =
      match node.process with
      | Some process -> (
          (* Send SIGTERM and wait for a bounded time; if the process does not
             exit, escalate to SIGKILL and wait unconditionally so that a
             daemon ignoring SIGTERM cannot stall cleanup forever. *)
          Signal.send_exn Signal.term (`Pid (Process.pid process)) ;
          let timeout = Time.Span.of_sec 10.0 in
          let%bind.Deferred wait_result =
            Clock.with_timeout timeout (Process.wait process)
          in
          match wait_result with
          | `Result _exit_or_signal ->
              Deferred.unit
          | `Timeout ->
              Signal.send_exn Signal.kill (`Pid (Process.pid process)) ;
              let%map.Deferred _exit_or_signal = Process.wait process in
              () )
      | None ->
          Deferred.unit
    in
    node.process <- None ;
    (* Drop the archive node's per-test database so repeated runs against a
       shared Postgres server stay clean. *)
    let%bind.Deferred () =
      match (node.config.node_type, node.config.postgres_connection_uri) with
      | Archive, Some uri ->
          drop_archive_db ~logger:(Logger.create ()) uri
      | _ ->
          Deferred.unit
    in
    return ()
end

type t =
  { namespace : string
  ; constants : Test_config.constants
  ; seeds : Node.t Core.String.Map.t
  ; block_producers : Node.t Core.String.Map.t
  ; snark_coordinators : Node.t Core.String.Map.t
  ; snark_workers : Node.t Core.String.Map.t
  ; archive_nodes : Node.t Core.String.Map.t
  ; genesis_keypairs : Network_keypair.t Core.String.Map.t
  }

let constants { constants; _ } = constants

let constraint_constants { constants; _ } = constants.constraint_constants

let genesis_constants { constants; _ } = constants.genesis_constants

let compile_config { constants; _ } = constants.compile_config

let seeds { seeds; _ } = seeds

let block_producers { block_producers; _ } = block_producers

let snark_coordinators { snark_coordinators; _ } = snark_coordinators

let archive_nodes { archive_nodes; _ } = archive_nodes

let all_mina_nodes { seeds; block_producers; snark_coordinators; _ } =
  List.concat
    [ Core.String.Map.to_alist seeds
    ; Core.String.Map.to_alist block_producers
    ; Core.String.Map.to_alist snark_coordinators
    ]
  |> Core.String.Map.of_alist_exn

let all_nodes t =
  List.concat
    [ Core.String.Map.to_alist t.seeds
    ; Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ]
  |> Core.String.Map.of_alist_exn

let all_non_seed_nodes t =
  List.concat
    [ Core.String.Map.to_alist t.block_producers
    ; Core.String.Map.to_alist t.snark_coordinators
    ; Core.String.Map.to_alist t.snark_workers
    ]
  |> Core.String.Map.of_alist_exn

let node_exn t key = Core.String.Map.find_exn (all_nodes t) key

let block_producer_exn t key = Core.String.Map.find_exn (block_producers t) key

let genesis_keypairs { genesis_keypairs; _ } = genesis_keypairs

let genesis_keypair_exn t key =
  Core.String.Map.find_exn (genesis_keypairs t) key

let initialize_infra ~logger network =
  let _ = logger in
  let _ = network in
  Malleable_error.return ()
