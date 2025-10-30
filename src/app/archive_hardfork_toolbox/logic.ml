open Async
open Core

type check_error = Success | Failure of string

type check_result = { id : string; name : string; result : check_error }

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
      Deferred.return pool

let is_in_best_chain ~postgres_uri ~fork_state_hash ~fork_height ~fork_slot () =
  let open Deferred.Let_syntax in
  let%bind pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in

  let%bind tip = query_db ~f:(fun db -> Sql.latest_state_hash db) in
  let%bind (in_chain : bool) =
    query_db ~f:(fun db ->
        Sql.is_in_the_best_chain db ~tip_hash:tip ~check_hash:fork_state_hash
          ~check_height:fork_height ~check_slot:(Int64.of_int fork_slot) () )
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
  Deferred.return [ check_result ]

let confirmations_check ~postgres_uri ~latest_state_hash ~fork_slot
    ~required_confirmations () =
  let open Deferred.Let_syntax in
  let%bind pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%bind confirmations =
    query_db ~f:(fun db ->
        Sql.no_of_confirmations db ~latest_state_hash ~fork_slot )
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
  Deferred.return [ check_result ]

let no_commands_after ~postgres_uri ~fork_state_hash ~fork_slot () =
  let open Deferred.Let_syntax in
  let%bind pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%bind _, _, _, user_commands_count =
    query_db ~f:(fun db ->
        Sql.number_of_user_commands_since_block db ~fork_state_hash ~fork_slot )
  in
  let%bind _, _, _, internal_commands_count =
    query_db ~f:(fun db ->
        Sql.number_of_internal_commands_since_block db ~fork_state_hash
          ~fork_slot )
  in

  let%bind _, _, _, zkapps_commands_count =
    query_db ~f:(fun db ->
        Sql.number_of_zkapps_commands_since_block db ~fork_state_hash ~fork_slot )
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
  Deferred.return [ check_result ]

let verify_upgrade ~postgres_uri ~version () =
  let open Deferred.Let_syntax in
  let results = ref [] in
  let%bind pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let%bind res =
    query_db ~f:(fun db -> Sql.SchemaVerification.fetch_schema_row db ~version)
  in
  let%bind missing_cols_zkapp_states =
    query_db ~f:(fun db ->
        Sql.SchemaVerification.fetch_missing_cols db ~table:"zkapp_states" )
  in
  let%bind missing_cols_zkapp_states_nullable =
    query_db ~f:(fun db ->
        Sql.SchemaVerification.fetch_missing_cols db
          ~table:"zkapp_states_nullable" )
  in

  let%bind () =
    match res with
    | None ->
        results :=
          { id = "4.S"
          ; name = "Schema migration status"
          ; result =
              Failure
                (sprintf "No schema migration found for version %s" version)
          }
          :: !results ;
        Deferred.return ()
    | Some status ->
        let expected = "applied" in
        let result =
          if String.equal status expected then Success
          else
            Failure
              (sprintf
                 "Expected schema migration with version %s to be \"%s\" \
                  however got status %s"
                 version expected status )
        in
        results :=
          { id = "4.S"; name = "Schema migration status"; result } :: !results ;
        Deferred.return ()
  in

  let%bind () =
    let result =
      if Int.( = ) missing_cols_zkapp_states 0 then Success
      else
        Failure
          (sprintf
             "Missing columns for zkapp_states detected during upgrade \
              verification: %d"
             missing_cols_zkapp_states )
    in
    results :=
      { id = "5.M"; name = "Missing columns check [zkapp_states]"; result }
      :: !results ;
    Deferred.return ()
  in

  let%bind () =
    let result =
      if Int.( = ) missing_cols_zkapp_states_nullable 0 then Success
      else
        Failure
          (sprintf
             "Missing columns for zkapp_states_nullable detected during \
              upgrade verification: %d"
             missing_cols_zkapp_states_nullable )
    in
    results :=
      { id = "6.M"
      ; name = "Missing columns check [zkapp_states_nullable]"
      ; result
      }
      :: !results ;
    Deferred.return ()
  in

  Deferred.return !results

let validate_fork ~postgres_uri ~fork_state_hash ~fork_slot () =
  let open Deferred.Let_syntax in
  let%bind pool = connect postgres_uri in
  let query_db = Mina_caqti.query pool in
  let fork_slot = Int64.of_int fork_slot in

  let%bind last_fork_block = query_db ~f:(fun db -> Sql.last_fork_block db) in
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
  Deferred.return [ check_result ]
