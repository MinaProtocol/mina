open Core_kernel
open Signature_lib
open Mina_numbers
open Currency
open Mina_base

module Hash = struct
  type t = Ledger_hash.t

  let merge = Ledger_hash.merge

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = Ledger_hash.of_digest Account.empty_digest
end

let%test_module "transaction logic consistency" =
  ( module struct
    let precomputed_values = Lazy.force Precomputed_values.compiled_inputs

    let constraint_constants = precomputed_values.constraint_constants

    let block_data = precomputed_values.protocol_state_with_hash.data

    let current_slot = Global_slot.of_int 15

    let block_data =
      (* Tweak block data to have current slot. *)
      let open Mina_state.Protocol_state in
      let consensus_state =
        Consensus.Data.Consensus_state.Value.For_tests
        .with_global_slot_since_genesis
          (consensus_state block_data)
          current_slot
      in
      create_value
        ~previous_state_hash:(previous_state_hash block_data)
        ~genesis_state_hash:(genesis_state_hash block_data)
        ~blockchain_state:(blockchain_state block_data)
        ~consensus_state ~constants:(constants block_data)
      |> body

    let txn_state_view = Mina_state.Protocol_state.Body.view block_data

    let state_body_hash = Mina_state.Protocol_state.Body.hash block_data

    let coinbase_stack_source = Pending_coinbase.Stack.empty

    let pending_coinbase_stack_target (t : Transaction.t) stack =
      let stack_with_state =
        Pending_coinbase.Stack.(push_state state_body_hash stack)
      in
      let target =
        match t with
        | Coinbase c ->
            Pending_coinbase.(Stack.push_coinbase c stack_with_state)
        | _ ->
            stack_with_state
      in
      target

    (*let next_available_token_before = Token_id.(next default)*)

    let empty_sparse_ledger account_ids =
      let base_ledger =
        Ledger.create_ephemeral ~depth:constraint_constants.ledger_depth ()
      in
      let count = ref 0 in
      List.iter account_ids ~f:(fun account_id ->
          let (_ : _ * _) = Ledger.create_empty_exn base_ledger account_id in
          incr count ) ;
      Sparse_ledger.of_ledger_subset_exn base_ledger account_ids

    (* Helpers for applying transactions *)

    module Sparse_txn_logic = Transaction_logic.Make (Sparse_ledger.L)

    let sparse_ledger ledger t =
      Or_error.try_with ~backtrace:true (fun () ->
          Sparse_ledger.apply_transaction_exn ~constraint_constants
            ~txn_state_view ledger (Transaction.forget t) )

    let transaction_logic ledger t =
      let ledger = ref ledger in
      let target_ledger =
        Sparse_txn_logic.apply_transaction ~constraint_constants
          ~txn_state_view ledger (Transaction.forget t)
      in
      Or_error.map ~f:(const !ledger) target_ledger

    let transaction_snark ~source ~target transaction =
      Or_error.try_with ~backtrace:true (fun () ->
          Transaction_snark.check_transaction ~constraint_constants
            ~sok_message:
              {Sok_message.fee= Fee.zero; prover= Public_key.Compressed.empty}
            ~source:(Sparse_ledger.merkle_root source)
            ~target:(Sparse_ledger.merkle_root target)
            ~init_stack:coinbase_stack_source
            ~pending_coinbase_stack_state:
              { source= coinbase_stack_source
              ; target=
                  pending_coinbase_stack_target
                    (Transaction.forget transaction)
                    coinbase_stack_source }
            ~next_available_token_before:
              (Sparse_ledger.next_available_token source)
            ~next_available_token_after:
              (Sparse_ledger.next_available_token target)
            ~snapp_account1:None ~snapp_account2:None {transaction; block_data}
            (unstage (Sparse_ledger.handler source)) )

    let check_consistent source transaction =
      let res_sparse = sparse_ledger source transaction in
      let res_txn_logic = transaction_logic source transaction in
      let target =
        match (res_sparse, res_txn_logic) with
        | Error _, Error _ ->
            source
        | Ok target1, Ok target2 ->
            assert (
              Ledger_hash.equal
                (Sparse_ledger.merkle_root target1)
                (Sparse_ledger.merkle_root target2) ) ;
            target1
        | Ok _target, Error err ->
            (*Error.tag err
              ~tag:"transaction logic failed when sparse ledger didn't"
            |> Error.raise*)
            ignore err ; _target
        | Error err, Ok _ ->
            Error.tag err
              ~tag:"sparse ledger failed when transaction logic didn't"
            |> Error.raise
      in
      let res_snark = transaction_snark ~source ~target transaction in
      match (res_sparse, res_snark) with
      | Ok _, Ok _ | Error _, Error _ ->
          ()
      | Ok _, Error err ->
          Error.tag err
            ~tag:"transaction snark failed when other implementations didn't"
          |> Error.raise
      | Error err1, Ok _ ->
          let errs =
            match res_txn_logic with
            | Ok _ ->
                [err1]
            | Error err2 ->
                [err1; err2]
          in
          Error.of_list errs
          |> Error.tag
               ~tag:
                 "transaction snark passed when other implementations didn't"
          |> Error.raise

    let timed_specs public_key =
      let open Quickcheck.Generator.Let_syntax in
      let untimed =
        let%map balance = Balance.gen in
        Some
          (Account.create
             (Account_id.create public_key Token_id.default)
             balance)
      in
      let timed cliff_time vesting_period =
        let%bind balance = Balance.gen in
        let%bind moveable_amount = Amount.gen in
        let%bind cliff_amount = Amount.gen in
        let%map vesting_increment = Amount.gen in
        Some
          ( Account.create_timed
              (Account_id.create public_key Token_id.default)
              balance
              ~initial_minimum_balance:
                ( Balance.sub_amount balance moveable_amount
                |> Option.value ~default:Balance.zero )
              ~cliff_time:(Global_slot.of_int cliff_time)
              ~vesting_period:(Global_slot.of_int vesting_period)
              ~cliff_amount ~vesting_increment
          |> Or_error.ok_exn )
      in
      [ return None
      ; untimed
      ; timed 0 1 (* vesting, already hit cliff at 0 *)
      ; timed 0 16 (* not yet vesting, already hit cliff at 0 *)
      ; timed 5 1 (* vesting, already hit cliff *)
      ; timed 5 16 (* not yet vesting, already hit cliff *)
      ; timed 15 1 (* not yet vesting, just hit cliff *)
      ; timed 30 1
        (* not yet vesting, hasn't hit cliff *) ]

    let gen_account pk =
      let open Quickcheck.Generator.Let_syntax in
      let choices = timed_specs pk in
      let%bind choice = Quickcheck.Generator.of_list choices in
      choice

    let transaction_specs sender_sk sender' sender receiver =
      let open Quickcheck.Generator.Let_syntax in
      let gen_user_command_common =
        let%bind fee = Fee.gen in
        let%bind nonce =
          Account_nonce.gen_incl (Account_nonce.of_int 0)
            (Account_nonce.of_int 3)
        in
        let%bind valid_until = Global_slot.gen in
        let%bind memo_length =
          Int.gen_incl 0 Signed_command_memo.max_digestible_string_length
        in
        let%map memo = String.gen_with_length memo_length Char.gen_print in
        let memo =
          Signed_command_memo.create_by_digesting_string memo
          |> Or_error.ok_exn
        in
        ( { fee
          ; fee_token= Token_id.default
          ; fee_payer_pk= sender
          ; nonce
          ; valid_until
          ; memo }
          : Signed_command_payload.Common.t )
      in
      let payment =
        let%bind common = gen_user_command_common in
        let%map amount = Amount.gen in
        let body =
          Signed_command_payload.Body.Payment
            { source_pk= sender
            ; receiver_pk= receiver
            ; token_id= Token_id.default
            ; amount }
        in
        let payload : Signed_command_payload.t = {common; body} in
        let signed =
          Signed_command.sign
            {public_key= sender'; private_key= sender_sk}
            payload
        in
        Transaction.Command (User_command.Signed_command signed)
      in
      let delegation =
        let%map common = gen_user_command_common in
        let body =
          Signed_command_payload.Body.Stake_delegation
            (Set_delegate {delegator= sender; new_delegate= receiver})
        in
        let payload : Signed_command_payload.t = {common; body} in
        let signed =
          Signed_command.sign
            {public_key= sender'; private_key= sender_sk}
            payload
        in
        Transaction.Command (User_command.Signed_command signed)
      in
      let coinbase =
        let%bind amount = Amount.gen in
        if%bind Quickcheck.Generator.bool then
          let%map fee = Fee.gen in
          let res =
            Coinbase.create ~amount ~receiver:sender
              ~fee_transfer:
                (Some (Coinbase_fee_transfer.create ~receiver_pk:receiver ~fee))
          in
          match res with
          | Ok res ->
              Transaction.Coinbase res
          | Error _ ->
              Transaction.Coinbase
                ( Coinbase.create ~amount ~receiver:sender ~fee_transfer:None
                |> Or_error.ok_exn )
        else
          return
            (Transaction.Coinbase
               ( Coinbase.create ~amount ~receiver:sender ~fee_transfer:None
               |> Or_error.ok_exn ))
      in
      let fee_transfer =
        let single_ft pk =
          let%map fee = Fee.gen in
          Fee_transfer.Single.create ~receiver_pk:pk ~fee
            ~fee_token:Token_id.default
        in
        if%bind Quickcheck.Generator.bool then
          let%map fst = single_ft sender in
          Transaction.Fee_transfer
            (Fee_transfer.of_singles (`One fst) |> Or_error.ok_exn)
        else
          let%bind fst = single_ft receiver in
          let%map snd = single_ft sender in
          Transaction.Fee_transfer
            (Fee_transfer.of_singles (`Two (fst, snd)) |> Or_error.ok_exn)
      in
      ignore coinbase ;
      ignore fee_transfer ;
      [payment; delegation (*coinbase; fee_transfer*)]

    let gen_transaction sender_sk sender' sender receiver =
      let open Quickcheck.Generator.Let_syntax in
      let choices = transaction_specs sender_sk sender' sender receiver in
      let%bind choice = Quickcheck.Generator.of_list choices in
      choice

    let gen_ledger_and_txn =
      let open Quickcheck.Generator.Let_syntax in
      let%bind sk1 = Private_key.gen in
      let pk1' = Public_key.of_private_key_exn sk1 in
      let pk1 = Public_key.compress pk1' in
      let%bind account1 = gen_account pk1 in
      let%bind pk2, account2 =
        if%bind Quickcheck.Generator.bool then return (pk1, account1)
        else
          let%bind pk = Public_key.Compressed.gen in
          let%map account = gen_account pk in
          (pk, account)
      in
      let account_ids =
        List.map ~f:(fun pk -> Account_id.create pk Token_id.default) [pk1; pk2]
        |> List.dedup_and_sort ~compare:Account_id.compare
      in
      let ledger = ref (empty_sparse_ledger account_ids) in
      let add_to_ledger pk account =
        Option.iter account ~f:(fun account ->
            Sparse_ledger.L.get_or_create_account ledger
              (Account_id.create pk Token_id.default)
              account
            |> Or_error.ok_exn |> ignore )
      in
      add_to_ledger pk1 account1 ;
      add_to_ledger pk2 account2 ;
      let ledger = !ledger in
      let%map transaction = gen_transaction sk1 pk1' pk1 pk2 in
      (ledger, transaction)

    let%test "transaction logic is consistent between implementations" =
      let fail = ref false in
      Quickcheck.test ~trials:1000 gen_ledger_and_txn
        ~f:(fun (ledger, transaction) ->
          try check_consistent ledger transaction
          with exn ->
            let error = Error.of_exn ~backtrace:`Get exn in
            fail := true ;
            Format.printf
              "The following transaction was inconsistently \
               applied:@.%s@.%s@.%s@."
              (Yojson.Safe.pretty_to_string
                 (Transaction.Valid.to_yojson transaction))
              (Yojson.Safe.to_string (Sparse_ledger.to_yojson ledger))
              (Yojson.Safe.pretty_to_string (Error_json.error_to_yojson error))
      ) ;
      !fail
  end )
