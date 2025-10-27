open Core
open Async
open Mina_base
open Frontier_base
module Persistent_frontier_database =
  Transition_frontier.Persistent_frontier.Database

let load_root_identifier ~root_directory =
  let root_file = root_directory ^/ "root" in
  match Core.Unix.access root_file [ `Exists; `Read ] with
  | Error _ ->
      None
  | Ok () ->
      let fd = Core.Unix.openfile root_file ~mode:[ O_RDONLY ] in
      let buf_size = Int64.to_int_exn Core.Unix.((fstat fd).st_size) in
      let buf =
        Bigarray.(
          array1_of_genarray
            (Core.Unix.map_file fd char c_layout ~shared:false [| buf_size |]))
      in
      let root_identifier =
        Root_identifier.Stable.Latest.bin_read_t buf ~pos_ref:(ref 0)
      in
      Bigstring.unsafe_destroy buf ;
      Core.Unix.close fd ;
      Some root_identifier

let rec find_path_to_target ~db ~current_hash ~target_hash ~visited =
  if State_hash.equal current_hash target_hash then
    (* Found it! Return empty path since current is the target *)
    Ok []
  else if State_hash.Set.mem visited current_hash then
    (* Already visited this node, not in this branch *)
    Error "Target not found in frontier"
  else
    let visited = State_hash.Set.add visited current_hash in
    match Persistent_frontier_database.get_arcs db current_hash with
    | Error _ ->
        Error "Failed to read arcs from database"
    | Ok arcs ->
        (* Try each successor *)
        List.fold arcs ~init:(Error "Target not found in this branch")
          ~f:(fun acc succ_hash ->
            match acc with
            | Ok path ->
                (* Already found in another branch *)
                Ok path
            | Error _ -> (
                (* Try this branch *)
                match
                  find_path_to_target ~db ~current_hash:succ_hash ~target_hash
                    ~visited
                with
                | Ok path ->
                    Ok (current_hash :: path)
                | Error _ as e ->
                    e ) )

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

let load_persistent_root_hash ~logger ~config_directory
    ~persistent_root_location =
  match load_root_identifier ~root_directory:config_directory with
  | None ->
      [%log' error logger]
        "Could not load persistent root identifier from $location"
        ~metadata:[ ("location", `String persistent_root_location) ] ;
      Error "Failed to load persistent root identifier"
  | Some persistent_root_id ->
      let persistent_root_hash = persistent_root_id.state_hash in
      [%log' info logger] "Loaded persistent root with state hash: $hash"
        ~metadata:[ ("hash", State_hash.to_yojson persistent_root_hash) ] ;
      Ok persistent_root_hash

let get_frontier_root_hash ~logger ~db =
  match Persistent_frontier_database.get_root_hash db with
  | Error err ->
      [%log' error logger] "Failed to get frontier root hash: $error"
        ~metadata:
          [ ("error", `String (Persistent_frontier_database.Error.message err))
          ] ;
      Error "Failed to get frontier root hash"
  | Ok frontier_root_hash ->
      [%log' info logger] "Current frontier root hash: $hash"
        ~metadata:[ ("hash", State_hash.to_yojson frontier_root_hash) ] ;
      Ok frontier_root_hash

let find_garbage_blocks ~logger ~db ~frontier_root_hash ~persistent_root_hash =
  if State_hash.equal frontier_root_hash persistent_root_hash then (
    [%log' info logger]
      "Frontier root already matches persistent root. Nothing to do." ;
    Ok `Already_matches )
  else
    match
      find_path_to_target ~db ~current_hash:frontier_root_hash
        ~target_hash:persistent_root_hash ~visited:State_hash.Set.empty
    with
    | Error msg ->
        [%log' error logger] "Persistent root not found in frontier: $error"
          ~metadata:[ ("error", `String msg) ] ;
        Error
          "Persistent root state hash not found in frontier. Bootstrap \
           required."
    | Ok garbage_blocks ->
        [%log' info logger]
          "Found persistent root in frontier. Moving root forward, dropping \
           $count blocks."
          ~metadata:[ ("count", `Int (List.length garbage_blocks)) ] ;
        Ok (`Found_path garbage_blocks)

let load_new_root_data ~db ~persistent_root_hash =
  let open Result.Let_syntax in
  (* TODO make a CLI argument *)
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let proof_cache_db = Proof_cache_tag.create_identity_db () in
  (* Get the transition for the new root *)
  let%bind new_root_transition =
    Persistent_frontier_database.get_transition ~signature_kind ~proof_cache_db
      db persistent_root_hash
    |> Result.map_error ~f:(fun err ->
           Persistent_frontier_database.Error.message err )
  in
  (* Get the protocol states for the root scan state *)
  let%bind protocol_states =
    Persistent_frontier_database.get_protocol_states_for_root_scan_state db
    |> Result.map_error ~f:(fun err ->
           Persistent_frontier_database.Error.message err )
  in
  (* Get the current root minimal data *)
  let%bind current_root_minimal =
    Persistent_frontier_database.get_root db
    |> Result.map_error ~f:(fun err ->
           Persistent_frontier_database.Error.message err )
  in
  (* Convert protocol states to the format needed by Minimal.upgrade *)
  let protocol_states_for_upgrade =
    List.map protocol_states ~f:(fun state ->
        let state_hash = (Mina_state.Protocol_state.hashes state).state_hash in
        (state_hash, state) )
  in
  (* Convert Stable Minimal to non-Stable Minimal *)
  let current_root_minimal_unstable : Root_data.Minimal.t =
    Root_data.Minimal.write_all_proofs_to_disk ~proof_cache_db ~signature_kind
      current_root_minimal
  in
  (* Use Minimal.upgrade to create the new Limited root data.
     Note: This uses the current root's scan state and pending coinbase,
     which is correct since we're moving the root forward. *)
  let new_root_limited_unstable =
    Root_data.Minimal.upgrade current_root_minimal_unstable
      ~transition:new_root_transition
      ~protocol_states:protocol_states_for_upgrade
  in
  (* Convert non-Stable Limited to Stable Limited *)
  let new_root_limited : Root_data.Limited.Stable.Latest.t =
    Root_data.Limited.read_all_proofs_from_disk new_root_limited_unstable
  in
  Ok new_root_limited

let apply_root_transition ~logger ~db ~frontier_root_hash ~new_root_limited
    ~garbage =
  [%log' info logger]
    "Successfully loaded new root data. Applying root transition..." ;
  let move_root_batch =
    Persistent_frontier_database.move_root ~old_root_hash:frontier_root_hash
      ~new_root:new_root_limited ~garbage
  in
  try
    Persistent_frontier_database.with_batch db ~f:(fun batch ->
        move_root_batch batch ) ;
    [%log' info logger]
      "Successfully moved frontier root to match persistent root" ;
    Deferred.return (Ok ())
  with exn ->
    [%log' error logger] "Failed to apply root transition: $error"
      ~metadata:[ ("error", `String (Exn.to_string exn)) ] ;
    Deferred.return
      (Error ("Failed to apply root transition: " ^ Exn.to_string exn))

let fix_persistent_frontier_root ~config_directory =
  let logger = Logger.create () in
  [%log' info logger] "Fixing persistent frontier root mismatch" ;
  let open Deferred.Let_syntax in
  let persistent_root_location = config_directory ^/ "root" in
  let persistent_frontier_location = config_directory ^/ "frontier" in
  (* Check if directories exist *)
  match%bind
    check_directories_exist ~logger ~persistent_root_location
      ~persistent_frontier_location
  with
  | Error _ as e ->
      Deferred.return e
  | Ok `No_frontier ->
      Deferred.return (Ok ())
  | Ok `Both_exist -> (
      (* Load the persistent root identifier *)
      match
        load_persistent_root_hash ~logger ~config_directory
          ~persistent_root_location
      with
      | Error _ as e ->
          Deferred.return e
      | Ok persistent_root_hash -> (
          (* Open the frontier database *)
          let db =
            Persistent_frontier_database.create ~logger
              ~directory:persistent_frontier_location
          in
          (* Get the frontier root hash *)
          let result =
            let open Result.Let_syntax in
            let%bind frontier_root_hash = get_frontier_root_hash ~logger ~db in
            (* Find garbage blocks to drop *)
            let%bind garbage_result =
              find_garbage_blocks ~logger ~db ~frontier_root_hash
                ~persistent_root_hash
            in
            match garbage_result with
            | `Already_matches ->
                Ok `Already_matches
            | `Found_path garbage_blocks ->
                (* Load the new root data *)
                let%map new_root_limited =
                  load_new_root_data ~db ~persistent_root_hash
                in
                `Ready_to_apply
                  (frontier_root_hash, new_root_limited, garbage_blocks)
          in
          match result with
          | Error err ->
              [%log' error logger] "$error" ~metadata:[ ("error", `String err) ] ;
              Persistent_frontier_database.close db ;
              Deferred.return (Error err)
          | Ok `Already_matches ->
              Persistent_frontier_database.close db ;
              Deferred.return (Ok ())
          | Ok (`Ready_to_apply (frontier_root_hash, new_root_limited, garbage))
            -> (
              match%bind
                apply_root_transition ~logger ~db ~frontier_root_hash
                  ~new_root_limited ~garbage
              with
              | Ok () ->
                  Persistent_frontier_database.close db ;
                  Deferred.return (Ok ())
              | Error _ as e ->
                  Persistent_frontier_database.close db ;
                  Deferred.return e ) ) )

let command =
  Command.async
    ~summary:
      "Fix persistent frontier root hash mismatch with persistent root \
       (updates root hash only)"
    (let open Command.Let_syntax in
    let%map_open config_directory = Cli_lib.Flag.conf_dir in
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
    match%bind fix_persistent_frontier_root ~config_directory:conf_dir with
    | Ok () ->
        printf "Persistent frontier root fix completed successfully.\n" ;
        Deferred.unit
    | Error msg ->
        eprintf "Failed to fix persistent frontier: %s\n" msg ;
        exit 1)
