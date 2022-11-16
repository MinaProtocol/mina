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

(* TODO: Find a home for this. *)
let test_zkapp_command ?expected_failure ?(memo = Signed_command_memo.empty)
    ?(fee = Currency.Fee.(of_nanomina_int_exn 100)) ~fee_payer_pk ~signers
    ~initialize_ledger ~finalize_ledger zkapp_command =
  let fee_payer : Account_update.Fee_payer.t =
    { body =
        { Account_update.Body.Fee_payer.dummy with
          public_key = fee_payer_pk
        ; fee
        }
    ; authorization = Signature.dummy
    }
  in
  let zkapp_command : Zkapp_command.t =
    Array.fold signers
      ~init:
        ({ fee_payer; account_updates = zkapp_command; memo } : Zkapp_command.t)
      ~f:(fun zkapp_command (pk_compressed, sk) ->
        Zkapps_examples.insert_signatures pk_compressed sk zkapp_command )
  in
  Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
      let aux = initialize_ledger ledger in
      Async.Thread_safe.block_on_async_exn (fun () ->
          check_zkapp_command_with_merges_exn ?expected_failure ledger
            [ zkapp_command ] ) ;
      finalize_ledger aux ledger )

let gen_keys () =
  let sk = Private_key.create () in
  let pk = Public_key.of_private_key_exn sk in
  let pk_compressed = Public_key.compress pk in
  (pk_compressed, sk)

let fee_to_create n =
  Genesis_constants.Constraint_constants.compiled.account_creation_fee
  |> Currency.Amount.of_fee
  |> (fun x -> Currency.Amount.scale x n)
  |> Option.value_exn

let fee_to_create_signed n =
  fee_to_create n |> Currency.Amount.Signed.of_unsigned
  |> Currency.Amount.Signed.negate

let int_to_amount amt =
  let magnitude, sgn = if amt < 0 then (-amt, Sgn.Pos) else (amt, Sgn.Neg) in
  { Currency.Signed_poly.magnitude =
      Currency.Amount.of_nanomina_int_exn magnitude
  ; sgn
  }

let%test_module "Tokens test" =
  ( module struct
    let () = Base.Backtrace.elide := false

    let pk, sk = gen_keys ()

    let token_id = Token_id.default

    let account_id = Account_id.create pk token_id

    let owned_token_id = Account_id.derive_token_id ~owner:account_id

    let vk = Lazy.force Zkapps_tokens.vk

    let mint_to_keys = gen_keys ()

    module Account_updates = struct
      let deploy ~balance_change =
        Zkapps_examples.Deploy_account_update.full ~balance_change pk token_id
          vk

      let initialize =
        let account_update, () =
          Async.Thread_safe.block_on_async_exn
            (Zkapps_tokens.initialize pk token_id)
        in
        account_update

      let mint_with_caller caller =
        let amount_to_mint = Currency.Amount.of_nanomina_int_exn 200 in
        let account_update, () =
          Async.Thread_safe.block_on_async_exn
            (Zkapps_tokens.mint ~owner_public_key:pk ~owner_token_id:token_id
               ~caller ~amount:amount_to_mint
               ~mint_to_public_key:(fst mint_to_keys) )
        in
        account_update

      let mint = mint_with_caller Token_id.default
    end

    let signers = [| (pk, sk); mint_to_keys |]

    let initialize_ledger ledger =
      let balance =
        let open Currency.Balance in
        let add_amount x y = add_amount y x in
        zero
        |> add_amount (Currency.Amount.of_nanomina_int_exn 500)
        |> Option.value_exn
        |> add_amount (fee_to_create 50)
        |> Option.value_exn
      in
      let account = Account.create account_id balance in
      let _, loc =
        Ledger.get_or_create_account ledger account_id account
        |> Or_error.ok_exn
      in
      loc

    let finalize_ledger loc ledger = Ledger.get ledger loc

    let%test_unit "Initialize and mint" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree Account_updates.mint
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons
             (Account_updates.deploy ~balance_change:(fee_to_create_signed 1))
        |> test_zkapp_command ~fee_payer_pk:pk ~signers ~initialize_ledger
             ~finalize_ledger
      in
      ignore account

    let%test_unit "Initialize, mint, transfer none" =
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             ( fst @@ Async.Thread_safe.block_on_async_exn
             @@ Zkapps_tokens.child_forest pk token_id [] )
        |> Zkapp_command.Call_forest.cons_tree Account_updates.mint
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons
             (Account_updates.deploy ~balance_change:(fee_to_create_signed 1))
        |> test_zkapp_command ~fee_payer_pk:pk ~signers ~initialize_ledger
             ~finalize_ledger
      in
      ignore account

    let%test_unit "Initialize, mint, transfer one fails" =
      let subtree =
        []
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true
                   ~balance_change:(int_to_amount (-1)) ~token_id:owned_token_id
             }
      in
      match
        Or_error.try_with (fun () ->
            Async.Thread_safe.block_on_async_exn
            @@ Zkapps_tokens.child_forest pk token_id subtree )
      with
      | Ok _ ->
          failwith
            "Should be unable to produce a proof when the balances do not sum \
             to 0"
      | Error _ ->
          ()

    let%test_unit "Initialize, mint, transfer two succeeds" =
      let subtree =
        []
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true
                   ~balance_change:(int_to_amount (-1)) ~token_id:owned_token_id
                   ~caller:owned_token_id
             }
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true ~balance_change:(int_to_amount 1)
                   ~token_id:owned_token_id ~caller:owned_token_id
             }
      in
      let account =
        []
        |> Zkapp_command.Call_forest.cons_tree
             ( fst @@ Async.Thread_safe.block_on_async_exn
             @@ Zkapps_tokens.child_forest pk token_id subtree )
        |> Zkapp_command.Call_forest.cons_tree Account_updates.mint
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons
             (Account_updates.deploy ~balance_change:(fee_to_create_signed 1))
        |> test_zkapp_command ~fee_payer_pk:pk ~signers ~initialize_ledger
             ~finalize_ledger
      in
      ignore account

    let%test_unit "Initialize, mint, transfer two succeeds, ignores non-token" =
      let subtree =
        []
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true
                   ~balance_change:(int_to_amount (-1)) ~token_id:owned_token_id
                   ~caller:owned_token_id
             }
        (* This account update should be ignored by the token zkApp. *)
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true
                   ~balance_change:(int_to_amount (-30))
                   ~token_id:Token_id.default ~caller:owned_token_id
             }
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true ~balance_change:(int_to_amount 1)
                   ~token_id:owned_token_id ~caller:owned_token_id
             }
      in
      let account =
        []
        (* This account update should bring the total balance back to 0,
           counteracting the effect of the ignored update above.
        *)
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true ~balance_change:(int_to_amount 30)
                   ~token_id:Token_id.default ~caller:Token_id.default
             }
        |> Zkapp_command.Call_forest.cons_tree
             ( fst @@ Async.Thread_safe.block_on_async_exn
             @@ Zkapps_tokens.child_forest pk token_id subtree )
        |> Zkapp_command.Call_forest.cons_tree Account_updates.mint
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons
             (Account_updates.deploy ~balance_change:(fee_to_create_signed 2))
        |> test_zkapp_command ~fee_payer_pk:pk ~signers ~initialize_ledger
             ~finalize_ledger
      in
      ignore account

    let%test_unit "Initialize, mint, transfer recursive succeeds, ignores \
                   non-token" =
      let subtree =
        []
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true
                   ~balance_change:(int_to_amount (-5)) ~token_id:owned_token_id
                   ~caller:owned_token_id
             }
             ~calls:
               ( []
               (* Delegate call, should be checked. *)
               |> Zkapp_command.Call_forest.cons
                    { Account_update.authorization =
                        Control.Signature Signature.dummy
                    ; body =
                        Zkapps_examples.mk_update_body (fst mint_to_keys)
                          ~use_full_commitment:true
                          ~balance_change:(int_to_amount 2)
                          ~token_id:owned_token_id ~caller:owned_token_id
                    }
                    ~calls:
                      (let call_token_id =
                         Account_id.derive_token_id
                           ~owner:
                             (Account_id.create (fst mint_to_keys)
                                owned_token_id )
                       in
                       []
                       (* Delegate call, should be checked. *)
                       |> Zkapp_command.Call_forest.cons
                            { Account_update.authorization =
                                Control.Signature Signature.dummy
                            ; body =
                                Zkapps_examples.mk_update_body
                                  (fst mint_to_keys) ~use_full_commitment:true
                                  ~balance_change:(int_to_amount 2)
                                  ~token_id:owned_token_id
                                  ~caller:owned_token_id
                            }
                       (* Call, should be skipped. *)
                       |> Zkapp_command.Call_forest.cons
                            { Account_update.authorization =
                                Control.Signature Signature.dummy
                            ; body =
                                Zkapps_examples.mk_update_body
                                  (fst mint_to_keys) ~use_full_commitment:true
                                  ~balance_change:(int_to_amount (-15))
                                  ~token_id:Token_id.default
                                  ~caller:call_token_id
                            }
                       (* Minting by delegate call should be ignored by the sum
                          check.
                       *)
                       |> Zkapp_command.Call_forest.cons_tree
                            (Account_updates.mint_with_caller owned_token_id)
                       (* Minting by call should be ignored by the sum check.
                       *)
                       |> Zkapp_command.Call_forest.cons_tree
                            (Account_updates.mint_with_caller call_token_id) )
               (* Minting should be ignored by the sum check. *)
               |> Zkapp_command.Call_forest.cons_tree
                    (Account_updates.mint_with_caller owned_token_id) )
        (* This account update should be ignored by the token zkApp. *)
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true
                   ~balance_change:(int_to_amount (-15))
                   ~token_id:Token_id.default ~caller:owned_token_id
             }
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true ~balance_change:(int_to_amount 1)
                   ~token_id:owned_token_id ~caller:owned_token_id
             }
      in
      let account =
        []
        (* This account update should bring the total balance back to 0,
           counteracting the effect of the ignored update above.
        *)
        |> Zkapp_command.Call_forest.cons
             { Account_update.authorization = Control.Signature Signature.dummy
             ; body =
                 Zkapps_examples.mk_update_body (fst mint_to_keys)
                   ~use_full_commitment:true ~balance_change:(int_to_amount 30)
                   ~token_id:Token_id.default ~caller:Token_id.default
             }
        |> Zkapp_command.Call_forest.cons_tree
             ( fst @@ Async.Thread_safe.block_on_async_exn
             @@ Zkapps_tokens.child_forest pk token_id subtree )
        |> Zkapp_command.Call_forest.cons_tree Account_updates.mint
        |> Zkapp_command.Call_forest.cons_tree Account_updates.initialize
        |> Zkapp_command.Call_forest.cons
             (Account_updates.deploy ~balance_change:(fee_to_create_signed 2))
        |> test_zkapp_command ~fee_payer_pk:pk ~signers ~initialize_ledger
             ~finalize_ledger
      in
      ignore account
  end )
