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

let convert_chain_to_canonical ~postgres_uri ~latest_block_state_hash
    ~expected_protocol_version_str ~stop_at_slot () =
  let expected_protocol_version =
    Sql.Protocol_version.of_string expected_protocol_version_str
  in
  let pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
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
  let%bind.Deferred.Or_error latest_block =
    match%map
      query_db
        ~f:(Sql.block_info_by_state_hash ~state_hash:latest_block_state_hash)
    with
    | Some info ->
        Or_error.return info
    | None ->
        Or_error.errorf "Cannot find block with state hash %s"
          latest_block_state_hash
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
  [%log info] "Marking chain from %s to %s as canonical for protocol version %s"
    oldest_block.state_hash latest_block_state_hash
    (Sql.Protocol_version.to_string expected_protocol_version) ;
  let canonical_block_ids =
    List.map blocks_to_ensure_canonical ~f:(fun b -> b.id)
  in
  let%map () =
    query_db
      ~f:
        (Sql.mark_pending_blocks_as_canonical_or_orphaned ~canonical_block_ids
           ~stop_at_slot )
  in
  Ok ()
