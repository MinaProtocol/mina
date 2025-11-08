open Core
open Async
open Mina_base

let analyze_block_file path =
  let open Deferred.Let_syntax in
  let%bind content = Reader.file_contents path in
  let buf = Bigstring.of_string content in
  let block =
    Persistent_frontier__Extended_block.Stable.V1.bin_read_t buf
      ~pos_ref:(ref 0)
  in
  let open Persistent_frontier__Extended_block.Stable.V1 in
  let open
    Persistent_frontier__Extended_block
    .Update_coinbase_stack_and_get_data_result_or_commands
    .Stable
    .V1 in
  (* 1. Header serialization size *)
  let header_size = Mina_block.Header.Stable.V2.bin_size_t block.header in
  printf "Header serialization size: %d bytes\n" header_size ;

  (* 2. Update_coinbase_stack_and_get_data_result analysis *)
  match block.update_coinbase_stack_and_get_data_result with
  | Update_coinbase_stack_and_get_data_result
      ( is_new_stack
      , witnesses
      , pc_action
      , stack_update
      , first_pass_ledger
      , mask_maps ) ->
      printf "\n--- Update_coinbase_stack_and_get_data_result fields ---\n" ;

      (* Field 1: bool *)
      let field1_size = if is_new_stack then 1 else 1 in
      printf "Field 1 (is_new_stack): %d byte\n" field1_size ;

      (* Field 2: witnesses list *)
      let witnesses_size =
        List.fold witnesses ~init:0 ~f:(fun acc w ->
            acc
            + Transaction_snark_scan_state.Transaction_with_witness
              .With_account_update_digests
              .Stable
              .V1
              .bin_size_t w )
      in
      printf "Field 2 (witnesses): %d bytes (%d witnesses)\n" witnesses_size
        (List.length witnesses) ;

      (* Field 3: Pending_coinbase action *)
      let field3_size =
        Pending_coinbase.Update.Action.Stable.V1.bin_size_t pc_action
      in
      printf "Field 3 (pending_coinbase action): %d bytes\n" field3_size ;

      (* Field 4: stack update variant *)
      let field4_size =
        match stack_update with
        | `Update_none ->
            1 (* variant tag *)
        | `Update_one stack ->
            1 + Pending_coinbase.Stack_versioned.Stable.V1.bin_size_t stack
        | `Update_two (stack1, stack2) ->
            1
            + Pending_coinbase.Stack_versioned.Stable.V1.bin_size_t stack1
            + Pending_coinbase.Stack_versioned.Stable.V1.bin_size_t stack2
      in
      printf "Field 4 (stack_update): %d bytes\n" field4_size ;

      (* Field 5: first_pass_ledger_end *)
      let field5_size =
        match first_pass_ledger with
        | `First_pass_ledger_end hash ->
            1 + Frozen_ledger_hash.Stable.V1.bin_size_t hash
      in
      printf "Field 5 (first_pass_ledger_end): %d bytes\n" field5_size ;

      (* Field 6: mask_maps *)
      let field6_size =
        Mina_ledger.Ledger.Mask_maps.Stable.V1.bin_size_t mask_maps
      in
      printf "Field 6 (mask_maps): %d bytes\n" field6_size ;

      (* 3. Diff analysis *)
      printf "\n--- Diff analysis ---\n" ;
      let diff_two, diff_one_opt = block.diff in

      (* Total diff size *)
      let diff_two_size =
        Staged_ledger_diff.Pre_diff_two.Stable.V2.bin_size_t
          Transaction_snark_work.Stable.V2.bin_size_t
          (fun _ -> 1)
          diff_two
      in
      let diff_one_size =
        match diff_one_opt with
        | None ->
            0
        | Some diff_one ->
            Staged_ledger_diff.Pre_diff_one.Stable.V2.bin_size_t
              Transaction_snark_work.Stable.V2.bin_size_t
              (fun _ -> 1)
              diff_one
      in
      let total_diff_size = diff_two_size + diff_one_size in
      printf "Total diff size: %d bytes (diff_two: %d, diff_one: %d)\n"
        total_diff_size diff_two_size diff_one_size ;

      (* Extract all transaction snark works *)
      let all_works =
        diff_two.completed_works
        @ match diff_one_opt with None -> [] | Some d -> d.completed_works
      in
      let works_count = List.length all_works in
      let works_size =
        List.fold all_works ~init:0 ~f:(fun acc work ->
            acc + Transaction_snark_work.Stable.V2.bin_size_t work )
      in
      printf "Transaction snark works: %d works, %d bytes total\n" works_count
        works_size ;

      (* Combined size of all proofs in works *)
      let proofs_size =
        List.fold all_works ~init:0 ~f:(fun acc work ->
            let proofs = Transaction_snark_work.Stable.V2.proofs work in
            acc
            + One_or_two.fold proofs ~init:0 ~f:(fun acc proof ->
                  acc + Ledger_proof.Stable.V2.bin_size_t proof ) )
      in
      printf "Combined proofs size in works: %d bytes\n" proofs_size ;

      (* 4. Transaction witnesses analysis *)
      printf "\n--- Transaction witnesses analysis ---\n" ;
      printf "Total witnesses size: %d bytes (%d witnesses)\n" witnesses_size
        (List.length witnesses) ;

      (* Extract user commands from witnesses *)
      let user_commands =
        List.filter_map witnesses ~f:(fun w ->
            let txn_applied =
              Transaction_snark_scan_state.Transaction_with_witness
              .With_account_update_digests
              .Stable
              .V1
              .transaction_with_info w
            in
            match txn_applied.varying with
            | Mina_transaction_logic.Transaction_applied.Varying.Command cmd ->
                Some cmd
            | _ ->
                None )
      in
      let user_commands_size =
        List.fold user_commands ~init:0 ~f:(fun acc cmd ->
            acc
            + Mina_transaction_logic.Transaction_applied.Command_applied.Stable
              .V2
              .bin_size_t
                (fun zkapp ->
                  Zkapp_command.With_account_update_digests.Stable.V1.bin_size_t
                    zkapp )
                cmd )
      in
      printf "User commands from witnesses: %d commands, %d bytes total\n"
        (List.length user_commands)
        user_commands_size ;
      let user_cmd_size ~f cmd =
        match cmd with
        | Mina_transaction_logic.Transaction_applied.Command_applied
          .Signed_command { common = { user_command = { data; _ } }; _ } ->
            User_command.Stable.Latest.bin_size_t (Signed_command data)
        | Mina_transaction_logic.Transaction_applied.Command_applied
          .Zkapp_command { command = { data; _ }; _ } ->
            1 + f data
      in
      let user_commands_stable_size =
        List.fold user_commands ~init:0 ~f:(fun acc cmd ->
            acc
            + user_cmd_size
                ~f:
                  (Fn.compose Zkapp_command.Stable.Latest.bin_size_t
                     Zkapp_command.With_account_update_digests.forget_digests )
                cmd )
      in
      let user_commands_with_digests_size =
        List.fold user_commands ~init:0 ~f:(fun acc cmd ->
            acc
            + user_cmd_size
                ~f:
                  Zkapp_command.With_account_update_digests.Stable.Latest
                  .bin_size_t cmd )
      in
      printf "User commands from witnesses (stable): %d bytes total\n"
        user_commands_stable_size ;
      printf "User commands from witnesses (with digests): %d bytes total\n"
        user_commands_with_digests_size ;
      (* Count zkapp commands *)
      let zkapp_count =
        List.fold user_commands ~init:0 ~f:(fun acc cmd ->
            match cmd with
            | Mina_transaction_logic.Transaction_applied.Command_applied
              .Signed_command _ ->
                acc
            | Mina_transaction_logic.Transaction_applied.Command_applied
              .Zkapp_command _ ->
                acc + 1 )
      in
      printf "Number of zkapp commands: %d\n" zkapp_count ;

      (* Calculate combined zkapp authorization field sizes *)
      let zkapp_auth_size =
        List.fold user_commands ~init:0 ~f:(fun acc cmd ->
            match cmd with
            | Mina_transaction_logic.Transaction_applied.Command_applied
              .Signed_command _ ->
                acc
            | Mina_transaction_logic.Transaction_applied.Command_applied
              .Zkapp_command zkapp_applied ->
                (* Get the zkapp command from With_status *)
                let zkapp_cmd = With_status.data zkapp_applied.command in
                (* Sum up all authorization field sizes in account updates *)
                let auth_size =
                  Zkapp_command.Call_forest.fold zkapp_cmd.account_updates
                    ~init:0 ~f:(fun acc au ->
                      acc + Control.Stable.V2.bin_size_t au.authorization )
                in
                acc + auth_size )
      in
      printf "Combined zkapp authorization field sizes: %d bytes\n"
        zkapp_auth_size ;

      Deferred.unit
  | _ ->
      printf
        "Block uses Commands representation (not \
         Update_coinbase_stack_and_get_data_result)\n" ;
      Deferred.unit

let command =
  Command.async ~summary:"Analyze byte sizes of an Extended_block file"
    (let open Command.Param in
    let file_path = anon ("file" %: string) in
    return (fun path () -> analyze_block_file path) <*> file_path)
