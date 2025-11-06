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
  let query_db ~f = Mina_caqti.query pool ~f in
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
  let query_db ~f = Mina_caqti.query pool ~f in
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
  let query_db ~f = Mina_caqti.query pool ~f in
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
  let query_db ~f = Mina_caqti.query pool ~f in
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
  let query_db ~f = Mina_caqti.query pool ~f in
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

let convert_chain_to_canonical ~postgres_uri ~target_block_hash
    ~protocol_version_str ~stop_at_slot () =
  let pool = connect postgres_uri in
  let query_db ~f = Mina_caqti.query pool ~f in
  let protocol_version = Sql.Protocol_version.of_string protocol_version_str in
  let%bind genesis_opt = query_db ~f:(Sql.genesis_block ~protocol_version) in
  let%bind.Deferred.Or_error genesis =
    match genesis_opt with
    | Some genesis ->
        Deferred.Or_error.return genesis
    | None ->
        Deferred.Or_error.errorf
          "Cannot locate genesis block for protocol version %s"
          protocol_version_str
  in
  let%bind target_opt =
    query_db ~f:(Sql.block_info_by_state_hash ~state_hash:target_block_hash)
  in
  let%bind.Deferred.Or_error target =
    match target_opt with
    | Some info ->
        Deferred.Or_error.return info
    | None ->
        Deferred.Or_error.errorf "Cannot find block with state hash %s"
          target_block_hash
  in
  let target_protocol_version_as_string =
    Sql.Protocol_version.to_string target.protocol_version
  in
  let%bind.Deferred.Or_error () =
    if String.( <> ) target_protocol_version_as_string protocol_version_str then
      Deferred.Or_error.errorf "Block %s uses protocol version %s, expected %s"
        target_block_hash target_protocol_version_as_string protocol_version_str
    else Deferred.Or_error.return ()
  in
  [%log info]
    "Marking chain leading to block %s (from %s) as canonical for protocol \
     version %s"
    target_block_hash genesis.state_hash target_protocol_version_as_string ;
  let%bind chain_ids =
    query_db
      ~f:
        (Sql.canonical_chain_ids ~target_block_id:target.id
           ~genesis_id:genesis.id ~protocol_version )
  in
  if List.is_empty chain_ids then
    Deferred.Or_error.errorf
      "Failed to compute canonical chain for block %s. Target block id %d, \
       genesis id %d. protocol version %s"
      target_block_hash target.id genesis.id target_protocol_version_as_string
  else
    (* Arbitrary batch size. Pending chain shouldn't be longer than this (k=290).
       If it is, we can increase the size or implement a more sophisticated
         batching mechanism.
    *)
    let batch_size = 500 in
    let batch_count =
      Int.((List.length chain_ids + batch_size - 1) / batch_size)
    in
    let current_batch = ref 1 in
    [%log info]
      "Marking %d blocks as canonical or orphaned for protocol version %s in \
       batches of %d"
      (List.length chain_ids) target_protocol_version_as_string batch_size ;
    let%map () =
      Deferred.List.iter (List.chunks_of chain_ids ~length:batch_size)
        ~f:(fun ids ->
          [%log info] "Marking [%d/%d] batch of blocks as canonical/orphaned"
            !current_batch batch_count ;
          current_batch := !current_batch + 1 ;
          query_db
            ~f:
              (Sql.mark_blocks_as_canonical_or_orphaned ~protocol_version ~ids
                 ~stop_at_slot ) )
    in
    Ok ()
