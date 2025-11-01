open Core
open Async
open Mina_base
open Frontier_base

(* Build path from frontier root to persistent root by walking backwards *)
let rec build_path_to_root ~(frontier : Transition_frontier.t) ~current_hash
    ~target_hash acc =
  if State_hash.equal current_hash target_hash then
    (* Reached the target (frontier root), return accumulated path *)
    Ok (List.rev acc)
  else
    match Transition_frontier.find frontier current_hash with
    | None ->
        Error
          (sprintf "Block %s not found in frontier"
             (State_hash.to_base58_check current_hash) )
    | Some breadcrumb ->
        let parent_hash = Breadcrumb.parent_hash breadcrumb in
        build_path_to_root ~frontier ~current_hash:parent_hash ~target_hash
          (breadcrumb :: acc)

let check_directories_exist ~logger ~persistent_root_location
    ~persistent_frontier_location =
  let open Deferred.Let_syntax in
  let%bind root_exists =
    Sys.file_exists persistent_root_location
    >>| function `Yes -> true | `No | `Unknown -> false
  in
  let%bind frontier_exists =
    Sys.file_exists persistent_frontier_location
    >>| function `Yes -> true | `No | `Unknown -> false
  in
  if not root_exists then (
    [%log' error logger] "Persistent root directory not found at $location"
      ~metadata:[ ("location", `String persistent_root_location) ] ;
    Deferred.return (Error "Persistent root not found - nothing to fix against")
    )
  else if not frontier_exists then (
    [%log' info logger]
      "Persistent frontier directory not found - nothing to fix" ;
    Deferred.return (Ok `No_frontier) )
  else Deferred.return (Ok `Both_exist)

(* Apply a sequence of root transition diffs to the persistent database *)
let apply_root_transitions ~logger ~db root_transition_diffs =
  try
    (* Get initial root hash *)
    let initial_root_hash =
      match
        Transition_frontier.Persistent_frontier.Database.get_root_hash db
      with
      | Ok h ->
          h
      | Error err ->
          failwith
            ( "Failed to get root hash: "
            ^ Transition_frontier.Persistent_frontier.Database.Error.message err
            )
    in
    Transition_frontier.Persistent_frontier.Database.with_batch db
      ~f:(fun batch ->
        let (_ : State_hash.t) =
          List.fold root_transition_diffs ~init:initial_root_hash
            ~f:(fun old_root_hash diff ->
              match diff with
              | Diff.Lite.E.E
                  (Diff.Root_transitioned
                    { new_root; garbage = Lite garbage; _ } ) ->
                  let move_root_fn =
                    Transition_frontier.Persistent_frontier.Database.move_root
                      ~old_root_hash ~new_root ~garbage
                  in
                  move_root_fn batch ;
                  (* Return new root hash for next iteration *)
                  (Root_data.Limited.Stable.Latest.hashes new_root).state_hash
              | _ ->
                  failwith "Expected Root_transitioned diff" )
        in
        () ) ;
    [%log' info logger] "Successfully applied $count root transitions"
      ~metadata:[ ("count", `Int (List.length root_transition_diffs)) ] ;
    Deferred.return (Ok ())
  with exn ->
    [%log' error logger] "Failed to apply root transitions: $error"
      ~metadata:[ ("error", `String (Exn.to_string exn)) ] ;
    Deferred.return
      (Error ("Failed to apply root transitions: " ^ Exn.to_string exn))

let fix_persistent_frontier_root_do ~logger ~config_directory
    ~chain_state_locations runtime_config =
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  (* Get compile-time constants *)
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let proof_level = Genesis_constants.Compiled.proof_level in
  let%bind.Deferred.Result precomputed_values, _runtime_config_opt =
    Genesis_ledger_helper.init_from_config_file ~genesis_constants
      ~constraint_constants ~logger ~proof_level ~cli_proof_level:None
      ~genesis_dir:chain_state_locations.Chain_state_locations.genesis
      ~genesis_backing_type:Stable_db runtime_config
    >>| Result.map_error ~f:Error.to_string_mach
  in
  (* Initialize Parallel as master before creating verifier *)
  Parallel.init_master () ;
  (* Create verifier - simplified without blockchain keys for now *)
  let%bind ( `Blockchain blockchain_verification_key
           , `Transaction transaction_verification_key ) =
    Verifier.get_verification_keys_eagerly ~constraint_constants ~proof_level
      ~signature_kind
  in
  let%bind verifier =
    Verifier.create ~logger ~commit_id:"" ~blockchain_verification_key
      ~transaction_verification_key ~signature_kind
      ~proof_level:precomputed_values.proof_level
      ~pids:(Child_processes.Termination.create_pid_table ())
      ~conf_dir:(Some config_directory) ()
  in
  (* Set up persistent root and frontier *)
  let persistent_root =
    Transition_frontier.Persistent_root.create ~logger ~backing_type:Stable_db
      ~directory:chain_state_locations.root
      ~ledger_depth:precomputed_values.constraint_constants.ledger_depth
  in
  let persistent_frontier =
    Transition_frontier.Persistent_frontier.create ~logger ~verifier
      ~directory:chain_state_locations.frontier
      ~time_controller:(Block_time.Controller.basic ~logger)
      ~signature_kind
  in
  let%bind.Deferred.Result proof_cache_db =
    Proof_cache_tag.create_db ~logger chain_state_locations.proof_cache
    >>| Result.map_error ~f:(fun (`Initialization_error err) ->
            Error.to_string_mach err )
  in
  let%bind.Deferred.Result root_transition =
    Persistent_frontier.with_instance_exn persistent_frontier
      ~f:
        (Persistent_frontier.Instance.get_root_transition ~proof_cache_db
           ~signature_kind )
  in
  let snarked_ledger_hash =
    Mina_block.Validated.header root_transition
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.blockchain_state
    |> Mina_state.Blockchain_state.snarked_ledger_hash
  in
  let%bind.Deferred.Result persistent_root_loaded =
    Persistent_root.load_from_disk_exn persistent_root ~snarked_ledger_hash
      ~logger
    |> Result.map_error ~f:(const "snarked ledger mismatch")
    |> Deferred.return
  in
  let persistent_root_id =
    Persistent_root.Instance.load_root_identifier persistent_root_loaded
    |> Option.value_exn ~message:"couldn't load persistent root hash"
  in
  let persistent_root_hash = persistent_root_id.state_hash in
  Persistent_root.Instance.set_root_state_hash persistent_root_loaded
    (Mina_block.Validated.state_hash root_transition) ;
  Persistent_root.Instance.close persistent_root_loaded ;
  (* Set up context module for frontier loading *)
  let module Context = struct
    let logger = logger

    let precomputed_values = precomputed_values

    let constraint_constants = precomputed_values.constraint_constants

    let consensus_constants = precomputed_values.consensus_constants

    let proof_cache_db = proof_cache_db

    let signature_kind = signature_kind
  end in
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location:chain_state_locations.epoch_ledger
      ~genesis_state_hash:
        (State_hash.With_state_hashes.state_hash
           precomputed_values.protocol_state_with_hashes )
      ~epoch_ledger_backing_type:Stable_db
      Signature_lib.Public_key.Compressed.Set.empty
  in
  (* Load transition frontier using the standard API *)
  let%bind frontier =
    match%map
      Transition_frontier.load
        ~context:(module Context)
        ~retry_with_fresh_db:false ~max_frontier_depth:5 ~verifier
        ~consensus_local_state ~persistent_root ~persistent_frontier
        ~catchup_mode:`Super ~set_best_tip:false ()
    with
    | Error err ->
        let err_str =
          match err with
          | `Failure s ->
              sprintf "Failure: %s" s
          | `Bootstrap_required ->
              "Bootstrap required"
          | `Persistent_frontier_malformed ->
              "Persistent frontier malformed"
          | `Snarked_ledger_mismatch ->
              "Snarked ledger mismatch"
        in
        [%log' error logger] "Failed to load transition frontier: $error"
          ~metadata:[ ("error", `String err_str) ] ;
        failwith (sprintf "Failed to load frontier: %s" err_str)
    | Ok f ->
        f
  in
  let frontier_root_hash =
    Transition_frontier.root frontier |> Breadcrumb.state_hash
  in

  (* Check if persistent root is in the frontier *)
  match
    ( State_hash.equal frontier_root_hash persistent_root_hash
    , Transition_frontier.find frontier persistent_root_hash )
  with
  | true, _ ->
      [%log' info logger]
        "Frontier root already matches persistent root. Nothing to do." ;
      let%bind () = Transition_frontier.close ~loc:__LOC__ frontier in
      Deferred.return (Ok ())
  | _, None ->
      [%log' error logger]
        "Persistent root $persistent_root not found in frontier. Bootstrap \
         required."
        ~metadata:
          [ ("persistent_root", State_hash.to_yojson persistent_root_hash)
          ; ("frontier_root", State_hash.to_yojson frontier_root_hash)
          ] ;
      let%bind () = Transition_frontier.close ~loc:__LOC__ frontier in
      Deferred.return
        (Error "Persistent root not found in frontier. Bootstrap required.")
  | _, Some _persistent_root_breadcrumb ->
      (* Build path from persistent root back to frontier root *)
      let%bind.Deferred.Result path =
        build_path_to_root ~frontier ~current_hash:persistent_root_hash
          ~target_hash:frontier_root_hash []
        |> Deferred.return
      in
      [%log info]
        "Built path from persistent root to frontier root: $length blocks"
        ~metadata:[ ("length", `Int (List.length path)) ] ;
      (* Generate root transition diffs for each step *)
      let root_transition_diffs =
        List.map path ~f:(fun breadcrumb ->
            let diff =
              Transition_frontier.calculate_root_transition_diff frontier
                breadcrumb
            in
            (* Convert Full diff to Lite diff *)
            Diff.Full.E.to_lite diff )
      in
      [%log info] "Generated $count root transition diffs"
        ~metadata:[ ("count", `Int (List.length root_transition_diffs)) ] ;
      (* Get database before closing frontier *)
      let persistent_frontier_for_db =
        Transition_frontier.persistent_frontier frontier
      in
      let persistent_frontier_instance =
        Transition_frontier.Persistent_frontier.create_instance_exn
          persistent_frontier_for_db
      in
      let db = persistent_frontier_instance.db in
      let%bind () = Transition_frontier.close ~loc:__LOC__ frontier in
      (* Apply the diffs to persistent frontier database *)
      let%map.Deferred.Result () =
        apply_root_transitions ~logger ~db root_transition_diffs
      in
      [%log info] "Successfully moved frontier root to match persistent root"

let fix_persistent_frontier_root ~config_directory ~config_file =
  Logger.Consumer_registry.register ~commit_id:"" ~id:Logger.Logger_id.mina
    ~processor:Internal_tracing.For_logger.processor
    ~transport:
      (Internal_tracing.For_logger.json_lines_rotate_transport
         ~directory:(config_directory ^ "/internal-tracing")
         () )
    () ;
  let logger = Logger.create ~id:Logger.Logger_id.mina () in
  let log_processor =
    Logger.Processor.pretty ~log_level:Logger.Level.Trace
      ~config:
        { Interpolator_lib.Interpolator.mode = After
        ; max_interpolation_length = 50
        ; pretty_print = true
        }
  in
  Logger.Consumer_registry.register ~commit_id:Mina_version.commit_id
    ~id:Logger.Logger_id.mina ~processor:log_processor
    ~transport:(Logger.Transport.stdout ())
    () ;
  let%bind () = Internal_tracing.toggle ~commit_id:"" ~logger `Enabled in
  (* Load the persistent root identifier *)
  (* Load and initialize precomputed values from config *)
  let%bind.Deferred.Result runtime_config_json =
    Genesis_ledger_helper.load_config_json config_file
    >>| Result.map_error ~f:Error.to_string_mach
  in
  let%bind.Deferred.Result runtime_config =
    Deferred.return @@ Runtime_config.of_yojson runtime_config_json
  in
  let chain_state_locations =
    Chain_state_locations.of_config ~conf_dir:config_directory runtime_config
  in
  (* Check if directories exist *)
  match%bind.Deferred.Result
    check_directories_exist ~logger
      ~persistent_root_location:chain_state_locations.root
      ~persistent_frontier_location:chain_state_locations.frontier
  with
  | `No_frontier ->
      Deferred.Result.return ()
  | `Both_exist ->
      fix_persistent_frontier_root_do ~logger ~config_directory
        ~chain_state_locations runtime_config

let command =
  Command.async
    ~summary:
      "Fix persistent frontier root hash mismatch with persistent root by \
       applying proper root transitions"
    (let open Command.Let_syntax in
    let%map_open config_directory = Cli_lib.Flag.conf_dir
    and config_file =
      flag "--config-file" ~aliases:[ "config-file" ]
        ~doc:"PATH path to a configuration file" (required string)
    in
    Cli_lib.Exceptions.handle_nicely
    @@ fun () ->
    let open Deferred.Let_syntax in
    let%bind conf_dir =
      match config_directory with
      | Some dir ->
          Deferred.return dir
      | None ->
          let%map home = Sys.home_directory () in
          home ^/ Cli_lib.Default.conf_dir_name
    in
    match%bind
      fix_persistent_frontier_root ~config_directory:conf_dir ~config_file
    with
    | Ok () ->
        printf "Persistent frontier root fix completed successfully.\n" ;
        Deferred.unit
    | Error msg ->
        eprintf "Failed to fix persistent frontier: %s\n" msg ;
        exit 1)
