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

(* Write the genesis ledger of the runtime config to genesis_accounts, at the
   height of the config's genesis block (the fork genesis when the config has
   [proof.fork]). Balance queries read an account no block touched from there.
   Continues an interrupted write; a written ledger is left as it is. *)
let populate_genesis_accounts ~postgres_uri ~runtime_config_file ~chunks_length
    () =
  let runtime_config =
    Yojson.Safe.from_file runtime_config_file
    |> Runtime_config.of_yojson |> Result.ok_or_failwith
  in
  let (module G) = Genesis_constants.profiled () in
  [%log info] "Populating genesis accounts from runtime config %s"
    runtime_config_file ;
  let%bind precomputed_values =
    Genesis_ledger_helper.init_from_config_file ~logger
      ~proof_level:G.proof_level ~genesis_constants:G.genesis_constants
      ~constraint_constants:G.constraint_constants ~cli_proof_level:None
      runtime_config
    >>| Or_error.ok_exn
  in
  let genesis_height =
    let With_hash.{ data = block; _ }, _ =
      Mina_block.genesis ~precomputed_values
    in
    Mina_block.blockchain_length block
    |> Mina_numbers.Length.to_uint32 |> Unsigned.UInt32.to_int64
  in
  let%bind accounts =
    Precomputed_values.genesis_ledger precomputed_values
    |> Lazy.force |> Mina_ledger.Ledger.to_list
  in
  let%bind (module Conn : Mina_caqti.CONNECTION) =
    match%map Mina_caqti.connect postgres_uri with
    | Ok conn ->
        conn
    | Error e ->
        failwith (Caqti_error.show e)
  in
  Monitor.protect ~finally:Conn.disconnect
  @@ fun () ->
  let metadata = [ ("height", `String (Int64.to_string genesis_height)) ] in
  match%map
    Archive_lib.Processor.Genesis_accounts.add ~chunk_size:chunks_length
      (module Conn)
      ~genesis_height accounts
  with
  | Error e ->
      failwith (Caqti_error.show e)
  | Ok `No_table ->
      failwith
        "The archive database has no genesis_accounts table; run upgrade.sql"
  | Ok `Already_loaded ->
      [%log info] "The genesis ledger at height $height is already written"
        ~metadata
  | Ok (`Added (count, resumed_after)) ->
      [%log info]
        "Wrote $count genesis ledger accounts at height $height, after \
         $resumed_after written before"
        ~metadata:
          ( ("count", `Int count)
          :: ("resumed_after", `Int resumed_after)
          :: metadata )

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

(* Settle the hard fork boundary of the newest fork genesis, with the same core
   the archive node runs at startup: Archive_lib.Settle_pending_blocks. [dry_run]
   rolls the change back and prints what it would change. *)
let convert_chain_to_canonical ~postgres_uri ~dry_run () =
  let pool = connect postgres_uri in
  match%map
    Mina_caqti.Pool.use
      (fun (module Conn : Mina_caqti.CONNECTION) ->
        Archive_lib.Settle_pending_blocks.run ~dry_run (module Conn) )
      pool
  with
  | Ok result ->
      Yojson.Safe.to_channel Out_channel.stdout
        (Archive_lib.Settle_pending_blocks.to_yojson result) ;
      Out_channel.newline Out_channel.stdout ;
      Ok ()
  | Error e ->
      Or_error.error_string (Caqti_error.show e)
