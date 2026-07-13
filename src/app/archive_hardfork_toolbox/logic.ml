open Async
open Core

type check_error = Success | Failure of string

type check_result = { id : string; name : string; result : check_error }

let logger = Logger.create ()

let check_result_to_string { id; name; result } =
  match result with
  | Success ->
      sprintf "✅ [%s] %s: PASSED" id name
  | Failure err ->
      sprintf "❌ [%s] %s: FAILED - %s" id name err

let report_all_checks results =
  let passed_checks =
    List.filter results ~f:(fun { result; _ } ->
        match result with Success -> true | _ -> false )
  in
  let failed_checks =
    List.filter results ~f:(fun { result; _ } ->
        match result with Failure _ -> true | _ -> false )
  in

  printf "\n=== CHECK REPORT ===\n" ;
  printf "Total checks: %d\n" (List.length results) ;
  printf "Passed: %d\n" (List.length passed_checks) ;
  printf "Failed: %d\n\n" (List.length failed_checks) ;

  printf "=== DETAILED RESULTS ===\n" ;
  List.iter results ~f:(fun result ->
      printf "%s\n" (check_result_to_string result) ) ;

  if List.is_empty failed_checks then printf "\n🎉 All checks passed!\n"
  else (
    printf "\n💥 Failed checks:\n" ;
    List.iter failed_checks ~f:(fun { id; name; _ } ->
        printf "  - [%s] %s\n" id name ) )

let has_failures results =
  List.exists results ~f:(fun { result; _ } ->
      match result with Failure _ -> true | _ -> false )

let connect postgres_uri =
  match Mina_caqti.connect_pool postgres_uri with
  | Error e ->
      failwithf "❌ Connection failed to db, due to: %s" (Caqti_error.show e) ()
  | Ok pool ->
      pool

(* Populate accounts_accessed for the genesis block described by the runtime
   config. When the config has [proof.fork] set, the genesis block is the fork
   genesis, so this attaches the full fork genesis ledger to the fork block. This
   is the same routine the archive runs at startup with --config-file; exposing it
   here lets operators repair an existing hardfork archive whose fork genesis was
   never populated (e.g. because the archive was not (re)started with the fork
   config). *)
let populate_genesis_accounts ~postgres_uri ~runtime_config_file ~chunks_length
    () =
  let runtime_config =
    Yojson.Safe.from_file runtime_config_file
    |> Runtime_config.of_yojson |> Result.ok_or_failwith
  in
  let genesis_constants = Genesis_constants.Compiled.genesis_constants in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let pool = connect postgres_uri in
  [%log info] "Populating genesis accounts from runtime config %s"
    runtime_config_file ;
  Archive_lib.Processor.add_genesis_accounts ~logger
    ~runtime_config_opt:(Some runtime_config) ~genesis_constants ~chunks_length
    ~constraint_constants pool

let is_in_best_chain ~postgres_uri ~fork_state_hash ~fork_height ~fork_slot () =
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in

  let%bind tip = query_db ~f:Sql.latest_state_hash in
  let%map (in_chain : bool) =
    query_db
      ~f:
        (Sql.is_in_best_chain ~tip_hash:tip ~check_hash:fork_state_hash
           ~check_height:fork_height ~check_slot:(Int64.of_int fork_slot) )
  in
  let result =
    if in_chain then Success
    else
      Failure
        (sprintf
           "Fork block %s at slot %d is not in the best chain ending with tip \
            %s"
           fork_state_hash fork_slot tip )
  in
  let check_result = { id = "1.B"; name = "Best chain validation"; result } in
  [ check_result ]

let confirmations_check ~postgres_uri ~latest_state_hash ~fork_slot
    ~required_confirmations () =
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%map confirmations =
    query_db ~f:(Sql.num_of_confirmations ~latest_state_hash ~fork_slot)
  in
  let result =
    if confirmations >= required_confirmations then Success
    else
      Failure
        (sprintf
           "Expected at least %d confirmations for the fork block %s at slot \
            %d, however got only %d"
           required_confirmations latest_state_hash fork_slot confirmations )
  in
  let check_result =
    { id = "2.C"; name = "Confirmation count check"; result }
  in
  [ check_result ]

let no_commands_after ~postgres_uri ~fork_state_hash ~fork_slot () =
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%bind _, _, _, user_commands_count =
    query_db
      ~f:(Sql.number_of_user_commands_since_block ~fork_state_hash ~fork_slot)
  in
  let%bind _, _, _, internal_commands_count =
    query_db
      ~f:
        (Sql.number_of_internal_commands_since_block ~fork_state_hash ~fork_slot)
  in

  let%map _, _, _, zkapps_commands_count =
    query_db
      ~f:(Sql.number_of_zkapps_commands_since_block ~fork_state_hash ~fork_slot)
  in

  let result =
    if
      user_commands_count = 0
      && internal_commands_count = 0
      && zkapps_commands_count = 0
    then Success
    else
      Failure
        (sprintf
           "Expected no user, internal or zkapps commands after the fork block \
            %s at slot %d, however got %d user commands and %d internal \
            commands and %d zkapps commands"
           fork_state_hash fork_slot user_commands_count internal_commands_count
           zkapps_commands_count )
  in
  let check_result =
    { id = "3.N"; name = "No commands after fork check"; result }
  in
  [ check_result ]

let verify_upgrade ~postgres_uri ~expected_protocol_version
    ~expected_migration_version () =
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%map res = query_db ~f:Sql.fetch_latest_migration_history in
  match res with
  | Some (status, protocol_version, migration_version) -> (
      let results = Queue.create () in
      if String.(status <> "applied") then
        Queue.enqueue results
          { id = "4.S"
          ; name = "Schema migration"
          ; result = Failure (sprintf "Latest migration has status %s" status)
          } ;
      if String.(protocol_version <> expected_protocol_version) then
        Queue.enqueue results
          { id = "4.S"
          ; name = "Schema migration"
          ; result =
              Failure
                (sprintf
                   "Latest protool version mismatch: actual %s vs expected %s"
                   protocol_version expected_protocol_version )
          } ;
      if String.(migration_version <> expected_migration_version) then
        Queue.enqueue results
          { id = "4.S"
          ; name = "Schema migration"
          ; result =
              Failure
                (sprintf
                   "Latest migration version mismatch: actual %s vs expected %s"
                   migration_version expected_migration_version )
          } ;
      match Queue.to_list results with
      | [] ->
          [ { id = "4.S"; name = "Schema migration"; result = Success } ]
      | _ :: _ as results ->
          results )
  | None ->
      [ { id = "4.S"
        ; name = "Schema migration"
        ; result = Failure "Can't find latest migration record"
        }
      ]

let validate_fork ~postgres_uri ~fork_state_hash ~fork_slot () =
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let fork_slot = Int64.of_int fork_slot in

  let%map last_fork_block = query_db ~f:Sql.last_fork_block in
  let result =
    if
      String.equal (fst last_fork_block) fork_state_hash
      && Int64.equal (snd last_fork_block) fork_slot
    then Success
    else
      Failure
        (sprintf
           "Expected last fork block to be %s at slot %Ld, however got %s at \
            slot %Ld"
           (fst last_fork_block) (snd last_fork_block) fork_state_hash fork_slot )
  in
  let check_result = { id = "8.F"; name = "Fork validation"; result } in
  [ check_result ]

let fetch_last_filled_block ~postgres_uri () =
  let open Deferred.Let_syntax in
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%map hash, slot_since_genesis, height =
    query_db ~f:(fun db -> Sql.fetch_last_filled_block db)
  in

  let json =
    `Assoc
      [ ("state_hash", `String hash)
      ; ("slot_since_genesis", `Intlit (Int64.to_string slot_since_genesis))
      ; ("height", `Int height)
      ]
  in
  Yojson.Safe.to_channel Out_channel.stdout json ;
  Out_channel.newline Out_channel.stdout

let convert_chain_to_canonical ~postgres_uri ?target_block_hash ?fork_height
    ?protocol_version_str ?(json = false) ~stop_at_slot ~dry_run () =
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  (* Resolve the target block: an explicit state hash, an explicit height, or,
     when neither is given, auto-detect the parent of the latest hard-fork
     block (i.e. the last pre-fork block that should remain canonical). *)
  let%bind.Deferred.Or_error latest_block =
    match (target_block_hash, fork_height) with
    | Some _, Some _ ->
        Deferred.Or_error.errorf
          "Provide at most one of --target-block-hash or --fork-height"
    | Some state_hash, None -> (
        match%map query_db ~f:(Sql.block_info_by_state_hash ~state_hash) with
        | Some info ->
            Or_error.return info
        | None ->
            Or_error.errorf "Cannot find block with state hash %s" state_hash )
    | None, Some height -> (
        match%map
          query_db ~f:(Sql.blocks_info_by_height ~height:(Int64.of_int height))
        with
        | [ info ] ->
            Or_error.return info
        | [] ->
            Or_error.errorf "Cannot find any block at height %d" height
        | _ :: _ ->
            Or_error.errorf
              "Found multiple blocks at height %d; disambiguate with \
               --target-block-hash"
              height )
    | None, None -> (
        match%map query_db ~f:Sql.parent_of_latest_fork_block with
        | Some info ->
            Or_error.return info
        | None ->
            Or_error.errorf
              "Could not auto-detect a fork boundary (no hard-fork block with \
               a parent was found). Provide --target-block-hash or \
               --fork-height." )
  in
  let latest_block_state_hash = latest_block.state_hash in
  (* Protocol version: explicit override, otherwise the target block's own. *)
  let expected_protocol_version =
    match protocol_version_str with
    | Some s ->
        Sql.Protocol_version.of_string s
    | None ->
        latest_block.protocol_version
  in
  let expected_protocol_version_str =
    Sql.Protocol_version.to_string expected_protocol_version
  in
  let%bind.Deferred.Or_error oldest_block =
    match%map
      query_db
        ~f:(Sql.first_block_of_protocol_version ~v:expected_protocol_version)
    with
    | Some oldest_block ->
        Or_error.return oldest_block
    | None ->
        Or_error.errorf "Cannot locate genesis block for protocol version %s"
          expected_protocol_version_str
  in
  let%bind blocks_to_ensure_canonical =
    query_db
      ~f:
        (Sql.blocks_between_both_inclusive ~oldest_block_id:oldest_block.id
           ~latest_block_id:latest_block.id )
  in

  let%bind.Deferred.Or_error () =
    match blocks_to_ensure_canonical with
    | [] ->
        Deferred.Or_error.errorf
          "No blocks to mark as canonical found for target block %s and \
           expected_protocol_version %s "
          latest_block_state_hash expected_protocol_version_str
    | actual_oldest_block :: _
      when String.( <> ) actual_oldest_block.state_hash oldest_block.state_hash
      ->
        Deferred.Or_error.errorf
          "Chain ended at %s doesn't lead back to first block of \
           expected_protocol_version %s of state hash %s, this means there's \
           some inconsistency in DB"
          latest_block_state_hash expected_protocol_version_str
          oldest_block.state_hash
    | _ ->
        Deferred.Or_error.return ()
  in
  let problematic_blocks =
    List.filter_map blocks_to_ensure_canonical ~f:(fun b ->
        if
          Sql.Protocol_version.equal b.protocol_version
            expected_protocol_version
        then None
        else Some b )
  in
  let%bind.Deferred.Or_error () =
    if List.is_empty problematic_blocks then Deferred.Or_error.return ()
    else
      let message =
        List.map problematic_blocks ~f:(fun b ->
            Printf.sprintf "state hash %s has protocol version %s" b.state_hash
              (Sql.Protocol_version.to_string b.protocol_version) )
        |> String.concat ~sep:","
      in
      Deferred.Or_error.errorf "Some blocks have unexpected state hash: %s"
        message
  in
  let canonical_block_ids =
    List.map blocks_to_ensure_canonical ~f:(fun b -> b.id)
  in
  let canonical_count = List.length blocks_to_ensure_canonical in
  (* The hard fork just above the target, if any. Its slot is the upper bound that
     protects the post-fork chain when the fork keeps the same protocol version
     (see fork_block_above_height). None when the target is at the tip (no later
     fork), which preserves the previous behaviour. *)
  let%bind fork_context =
    query_db ~f:(Sql.fork_block_above_height ~height:latest_block.height)
  in
  let fork_boundary_slot =
    Option.map fork_context ~f:(fun fc -> fc.Sql.Fork_context.fork_slot)
  in
  (* The blocks that change status: the ancestry blocks not yet canonical
     (-> canonical), and the same-version off-chain blocks below the boundary
     (-> orphaned). The rest of the ancestry (including the protocol-version
     genesis) is already canonical and is not listed. *)
  let%bind blocks_to_heal =
    query_db ~f:(Sql.noncanonical_blocks_in_set ~canonical_block_ids)
  in
  let%bind blocks_to_orphan =
    query_db
      ~f:
        (Sql.blocks_to_orphan ~canonical_block_ids ~stop_at_slot
           ~fork_boundary_slot ~protocol_version:expected_protocol_version )
  in
  let%bind orphaned_count, pending_to_canonical, pending_to_orphaned =
    query_db
      ~f:
        (Sql.conversion_summary_counts ~canonical_block_ids ~stop_at_slot
           ~fork_boundary_slot ~protocol_version:expected_protocol_version )
  in
  (* Assemble the change plan: each block that changes, plus the fork block for
     context, with its current/new status and the reason. The already-canonical
     ancestry (including the protocol-version genesis) is not listed. *)
  let heal_changes =
    List.map blocks_to_heal ~f:(fun (height, hash, current) ->
        { Change_plan.Change.height
        ; state_hash = hash
        ; current
        ; new_status = "canonical"
        ; untouched = false
        ; reason =
            ( if String.equal hash latest_block_state_hash then
              "fork parent (target)"
            else "on chain to target" )
        } )
  in
  let orphan_changes =
    List.map blocks_to_orphan ~f:(fun (height, hash, current) ->
        { Change_plan.Change.height
        ; state_hash = hash
        ; current
        ; new_status = "orphaned"
        ; untouched = false
        ; reason = "off-chain / competing, below fork boundary"
        } )
  in
  let fork_change =
    match fork_context with
    | Some
        { Sql.Fork_context.fork_state_hash; fork_height; fork_chain_status; _ }
      ->
        [ { Change_plan.Change.height = fork_height
          ; state_hash = fork_state_hash
          ; current = fork_chain_status
          ; new_status = fork_chain_status
          ; untouched = true
          ; reason = "post-fork genesis (protected)"
          }
        ]
    | None ->
        []
  in
  let changes =
    List.sort
      (heal_changes @ orphan_changes @ fork_change)
      ~compare:(fun a b ->
        Int64.compare a.Change_plan.Change.height b.Change_plan.Change.height )
  in
  let plan =
    { Change_plan.dry_run
    ; target =
        { Change_plan.Block_ref.state_hash = latest_block_state_hash
        ; height = latest_block.height
        ; protocol_version = expected_protocol_version_str
        }
    ; fork_block =
        Option.map fork_context ~f:(fun fc ->
            let { Sql.Fork_context.fork_state_hash
                ; fork_height
                ; fork_slot
                ; fork_chain_status
                ; parent_state_hash
                ; parent_height
                } =
              fc
            in
            { Change_plan.Fork_ref.state_hash = fork_state_hash
            ; height = fork_height
            ; global_slot = fork_slot
            ; chain_status = fork_chain_status
            ; parent_state_hash
            ; parent_height
            } )
    ; boundary_slot = fork_boundary_slot
    ; summary =
        { Change_plan.Summary.to_canonical = canonical_count
        ; to_canonical_pending = pending_to_canonical
        ; to_orphaned = orphaned_count
        ; to_orphaned_pending = pending_to_orphaned
        }
    ; changes
    }
  in
  if json then Change_plan.render_json plan else Change_plan.render_human plan ;
  if dry_run then Deferred.Or_error.return ()
  else (
    if not json then
      [%log info]
        "Marking chain from %s to %s as canonical for protocol version %s"
        oldest_block.state_hash latest_block_state_hash
        expected_protocol_version_str ;
    let%map () =
      query_db
        ~f:
          (Sql.mark_pending_blocks_as_canonical_or_orphaned ~canonical_block_ids
             ~stop_at_slot ~fork_boundary_slot
             ~protocol_version:expected_protocol_version )
    in
    Ok () )
