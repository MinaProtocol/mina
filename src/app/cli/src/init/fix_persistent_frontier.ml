open Core
open Async
open Mina_base
open Frontier_base

(* Build path from frontier root to persistent root by walking backwards *)
let rec build_path_to_root ~(frontier : Transition_frontier.t) ~current_hash
    ~target_hash acc =
  if State_hash.equal current_hash target_hash then
    (* Reached the target (frontier root), return accumulated path *)
    Ok acc
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
  match%map
    Deferred.both
      (Sys.file_exists persistent_root_location)
      (Sys.file_exists persistent_frontier_location)
  with
  | (`No | `Unknown), _ ->
      [%log' error logger] "Persistent root directory not found at $location"
        ~metadata:[ ("location", `String persistent_root_location) ] ;
      Error "Persistent root not found - nothing to fix against"
  | _, (`No | `Unknown) ->
      [%log' info logger]
        "Persistent frontier directory not found - nothing to fix" ;
      Ok `No_frontier
  | _ ->
      Ok `Both_exist

(* Apply a sequence of root transition diffs to the persistent database *)
let apply_root_transitions ~logger ~db diffs =
  try
    (* Get initial root hash *)
    let initial_root_hash =
      Transition_frontier.Persistent_frontier.Database.get_root_hash db
      |> Result.map_error ~f:(fun err ->
             Exn.create_s
               (Sexp.of_string
                  ( "Failed to get root hash: "
                  ^ Transition_frontier.Persistent_frontier.Database.Error
                    .message err ) ) )
      |> Result.ok_exn
    in
    let final_state_hash =
      Transition_frontier.Persistent_frontier.Database.with_batch db
        ~f:(fun batch ->
          List.fold diffs ~init:initial_root_hash ~f:(fun old_root_hash diff ->
              match diff with
              | Diff.Lite.E.E
                  (Diff.Root_transitioned
                    { new_root; garbage = Lite garbage; _ } ) ->
                  let parent_hash =
                    Root_data.Limited.Stable.Latest.transition new_root
                    |> Mina_block.Validated.Stable.Latest.header
                    |> Mina_block.Header.protocol_state
                    |> Mina_state.Protocol_state.previous_state_hash
                  in
                  assert (State_hash.equal parent_hash old_root_hash) ;
                  Transition_frontier.Persistent_frontier.Database.move_root
                    ~old_root_hash ~new_root ~garbage batch ;
                  (* Return new root hash for next iteration *)
                  (Root_data.Limited.Stable.Latest.hashes new_root).state_hash
              | _ ->
                  failwith "Expected Root_transitioned diff" ) )
    in
    [%log' info logger] "Successfully applied $count diffs"
      ~metadata:
        [ ("count", `Int (List.length diffs))
        ; ("final_state_hash", Frozen_ledger_hash.to_yojson final_state_hash)
        ] ;
    Ok ()
  with exn ->
    [%log' error logger] "Failed to apply root transitions: $error"
      ~metadata:[ ("error", `String (Exn.to_string exn)) ] ;
    Error ("Failed to apply root transitions: " ^ Exn.to_string exn)

let fix_persistent_frontier_root_do ~logger ~config_directory
    ~chain_state_locations ~max_frontier_depth runtime_config =
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
  let tmp_root_location = chain_state_locations.root ^ "-tmp" in
  let%bind.Deferred.Result () =
    Mina_stdlib_unix.File_system.copy_dir chain_state_locations.root
      tmp_root_location
    >>| Result.map_error ~f:Exn.to_string
  in
  (* Set up persistent root and frontier *)
  let persistent_root =
    Persistent_root.create ~logger ~backing_type:Stable_db
      ~directory:tmp_root_location
      ~ledger_depth:precomputed_values.constraint_constants.ledger_depth
  in
  let persistent_frontier =
    Persistent_frontier.create ~logger ~verifier
      ~directory:chain_state_locations.frontier
      ~time_controller:(Block_time.Controller.basic ~logger)
      ~signature_kind
  in
  let proof_cache_db = Proof_cache_tag.create_identity_db () in
  let%bind.Deferred.Result persistent_frontier_root_hash =
    Persistent_frontier.with_instance_exn persistent_frontier
      ~f:Persistent_frontier.Instance.get_root_hash
  in
  let%bind.Deferred.Result persistent_root_id =
    Deferred.return
    @@
    match Persistent_root.load_root_identifier persistent_root with
    | Some id ->
        Ok id
    | None ->
        Error "couldn't load persistent root hash"
  in
  let persistent_root_hash = persistent_root_id.state_hash in
  Persistent_root.set_root_state_hash persistent_root
    persistent_frontier_root_hash ;
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
  (* TODO loading of frontier is redundant unless fixing is needed *)
  (* Load transition frontier using the standard API *)
  let%bind frontier =
    match%map
      Transition_frontier.load
        ~context:(module Context)
        ~retry_with_fresh_db:false ~max_frontier_depth ~verifier
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
  assert (State_hash.equal frontier_root_hash persistent_frontier_root_hash) ;
  let clean_frontier () =
    let%bind () = Transition_frontier.close ~loc:__LOC__ frontier in
    Mina_stdlib_unix.File_system.remove_dir tmp_root_location
  in
  (* Check if persistent root is in the frontier *)
  match
    ( State_hash.equal frontier_root_hash persistent_root_hash
    , Transition_frontier.find frontier persistent_root_hash )
  with
  | true, _ ->
      [%log info]
        "Frontier root already matches persistent root. Nothing to do." ;
      let%map () = clean_frontier () in
      Ok ()
  | _, None ->
      [%log error]
        "Persistent root $persistent_root not found in frontier. Bootstrap \
         required."
        ~metadata:
          [ ("persistent_root", State_hash.to_yojson persistent_root_hash)
          ; ("frontier_root", State_hash.to_yojson frontier_root_hash)
          ] ;
      let%map () = clean_frontier () in
      Error "Persistent root not found in frontier. Bootstrap required."
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
      assert (
        State_hash.equal
          (List.hd_exn path |> Breadcrumb.parent_hash)
          frontier_root_hash ) ;
      (* Generate root transition diffs for each step *)
      let _, diffs =
        let successors = Transition_frontier.successors frontier in
        let init =
          ( Transition_frontier.root frontier
          , Transition_frontier.protocol_states_for_root_scan_state frontier )
        in
        List.fold_map path ~init
          ~f:(fun (parent, protocol_states_for_root_scan_state) breadcrumb ->
            let root_transition =
              Transition_frontier.Util.calculate_root_transition_diff
                ~protocol_states_for_root_scan_state ~parent ~successors
                breadcrumb
            in
            let res =
              Diff.Full.E.to_lite (E (Root_transitioned root_transition))
            in
            ( ( breadcrumb
              , Transition_frontier.Util.to_protocol_states_map_exn
                @@ Root_data.Limited.Stable.Latest.protocol_states
                @@ root_transition.new_root )
            , res ) )
      in
      [%log info] "Generated $count transition diffs"
        ~metadata:[ ("count", `Int (List.length diffs)) ] ;
      let%bind () = clean_frontier () in
      (* Apply the diffs to persistent frontier database *)
      let%map.Deferred.Result () =
        Persistent_frontier.with_instance_exn persistent_frontier
          ~f:(fun instance ->
            apply_root_transitions ~logger ~db:instance.db diffs )
      in
      [%log info] "Successfully moved frontier root to match persistent root"

let fix_persistent_frontier_root ~config_directory ~config_file
    ~max_frontier_depth =
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
        ~chain_state_locations ~max_frontier_depth runtime_config

let command =
  Command.async
    ~summary:
      "Fix persistent frontier root hash mismatch with persistent root by \
       applying proper root transitions"
    (let open Command.Let_syntax in
    let%map_open config_directory = Cli_lib.Flag.conf_dir
    and config_file =
      flag "--config-file" ~doc:"PATH path to a configuration file"
        (required string)
    and max_frontier_depth =
      flag "--max-frontier-depth"
        ~doc:"INT maximum frontier depth (default: 10)" (optional int)
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
        ~max_frontier_depth:(Option.value max_frontier_depth ~default:10)
    with
    | Ok () ->
        printf "Persistent frontier root fix completed successfully.\n" ;
        Deferred.unit
    | Error msg ->
        eprintf "Failed to fix persistent frontier: %s\n" msg ;
        exit 1)
