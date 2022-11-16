open Transaction_snark_tests.Util
open Core_kernel
open Mina_base
open Signature_lib
module Impl = Pickles.Impls.Step
module Inner_curve = Snark_params.Tick.Inner_curve
module Nat = Pickles_types.Nat
module Local_state = Mina_state.Local_state
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment
module Statement = Transaction_snark.Statement

let%test_module "Tokens test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let sk = Private_key.create ()

    let pk = Public_key.of_private_key_exn sk

    let pk_compressed = Public_key.compress pk

    let token_id = Token_id.default

    let account_id = Account_id.create pk_compressed token_id

    let vk = Lazy.force Zkapps_tokens.vk

    module Account_updates = struct
      let deploy =
        Zkapps_examples.Deploy_account_update.full pk_compressed token_id vk

      let initialize =
        let account_update, () =
          Async.Thread_safe.block_on_async_exn
            (Zkapps_tokens.initialize pk_compressed token_id)
        in
        account_update

      let update_state =
        let new_state = List.init 8 ~f:(fun _ -> Snark_params.Tick.Field.one) in

        let account_update, () =
          Async.Thread_safe.block_on_async_exn
            (Zkapps_tokens.update_state pk_compressed token_id new_state)
        in
        account_update
    end

    let test_zkapp_command ?expected_failure zkapp_command =
      let memo = Signed_command_memo.empty in
      let transaction_commitment : Zkapp_command.Transaction_commitment.t =
        (* TODO: This is a pain. *)
        let account_updates_hash =
          Zkapp_command.Call_forest.hash zkapp_command
        in
        Zkapp_command.Transaction_commitment.create ~account_updates_hash
      in
      let fee_payer : Account_update.Fee_payer.t =
        { body =
            { Account_update.Body.Fee_payer.dummy with
              public_key = pk_compressed
            ; fee = Currency.Fee.(of_nanomina_int_exn 100)
            }
        ; authorization = Signature.dummy
        }
      in
      let memo_hash = Signed_command_memo.hash memo in
      let full_commitment =
        Zkapp_command.Transaction_commitment.create_complete
          transaction_commitment ~memo_hash
          ~fee_payer_hash:
            (Zkapp_command.Call_forest.Digest.Account_update.create
               (Account_update.of_fee_payer fee_payer) )
      in
      let sign_all ({ fee_payer; account_updates; memo } : Zkapp_command.t) :
          Zkapp_command.t =
        let fee_payer =
          match fee_payer with
          | { body = { public_key; _ }; _ }
            when Public_key.Compressed.equal public_key pk_compressed ->
              { fee_payer with
                authorization =
                  Schnorr.Chunked.sign sk
                    (Random_oracle.Input.Chunked.field full_commitment)
              }
          | fee_payer ->
              fee_payer
        in
        let account_updates =
          Zkapp_command.Call_forest.map account_updates ~f:(function
            | ({ body = { public_key; use_full_commitment; _ }
               ; authorization = Signature _
               } as account_update :
                Account_update.t )
              when Public_key.Compressed.equal public_key pk_compressed ->
                let commitment =
                  if use_full_commitment then full_commitment
                  else (transaction_commitment :> Impl.field)
                in
                { account_update with
                  authorization =
                    Signature
                      (Schnorr.Chunked.sign sk
                         (Random_oracle.Input.Chunked.field commitment) )
                }
            | account_update ->
                account_update )
        in
        { fee_payer; account_updates; memo }
      in
      let zkapp_command : Zkapp_command.t =
        sign_all { fee_payer; account_updates = zkapp_command; memo }
      in
      Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
          let account =
            Account.create account_id
              Currency.Balance.(
                Option.value_exn
                  (add_amount zero (Currency.Amount.of_nanomina_int_exn 500)))
          in
          let _, loc =
            Ledger.get_or_create_account ledger account_id account
            |> Or_error.ok_exn
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
              check_zkapp_command_with_merges_exn ?expected_failure ledger
                [ zkapp_command ] ) ;
          Ledger.get ledger loc )

    let%test_unit "Initialize" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons Account_updates.deploy
        |> test_zkapp_command
      in
      let zkapp_state =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal zero) x))
        zkapp_state

    let%test_unit "Initialize and update" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.update_state
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons Account_updates.deploy
        |> test_zkapp_command
      in
      let zkapp_state =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal one) x))
        zkapp_state

    let%test_unit "Initialize and multiple update" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.update_state
        |> Zkapp_command.Call_forest.cons_tree Account_updates.update_state
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons Account_updates.deploy
        |> test_zkapp_command
      in
      let zkapp_state =
        (Option.value_exn (Option.value_exn account).zkapp).app_state
      in
      Pickles_types.Vector.iter
        ~f:(fun x -> assert (Snark_params.Tick.Field.(equal one) x))
        zkapp_state

    let%test_unit "Update without initialize fails" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.update_state
        |> Zkapp_command.Call_forest.cons Account_updates.deploy
        |> test_zkapp_command
             ~expected_failure:Account_proved_state_precondition_unsatisfied
      in
      assert (Option.is_none (Option.value_exn account).zkapp)

    let%test_unit "Double initialize fails" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons Account_updates.deploy
        |> test_zkapp_command
             ~expected_failure:Account_proved_state_precondition_unsatisfied
      in
      assert (Option.is_none (Option.value_exn account).zkapp)

    let%test_unit "Initialize after update fails" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons_tree Account_updates.update_state
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons Account_updates.deploy
        |> test_zkapp_command
             ~expected_failure:Account_proved_state_precondition_unsatisfied
      in
      assert (Option.is_none (Option.value_exn account).zkapp)

    let%test_unit "Initialize without deploy fails" =
      let account =
        Or_error.try_with (fun () ->
            (* Raises an exception due to verifying a proof without a valid vk
               in the account.
            *)
            []
            |> Zkapp_command.Call_forest.cons_tree Account_updates.update_state
            |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
            |> test_zkapp_command )
      in
      assert (Or_error.is_error account)
  end )
