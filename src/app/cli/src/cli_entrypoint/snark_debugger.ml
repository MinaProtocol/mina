open Core
open Async
open Consensus.Data
open Mina_base
open Mina_ledger
open Mina_numbers
open Mina_state
open Mina_transaction
open Signature_lib

(* TODO: these should be parameters *)
let apply_log = "transaction_apply.log"

let snark_log = "transaction_snark.log"

let debug_apply' ~logger ~constraint_constants ~protocol_state_view ~global_slot
    ~first_pass_ledger ~second_pass_ledger_opt transaction =
  let open Or_error.Let_syntax in
  [%log info] "Applying transaction out-of-snark" ;
  let res =
    Out_channel.with_file apply_log ~f:(fun channel ->
        let log = Mina_transaction_logic.Log.Channel channel in
        let%bind first_pass_output_ledger, partially_applied =
          Sparse_ledger.apply_transaction_first_pass ~log ~constraint_constants
            ~global_slot ~txn_state_view:protocol_state_view first_pass_ledger
            transaction
        in
        let second_pass_ledger =
          Option.value second_pass_ledger_opt ~default:first_pass_output_ledger
        in
        let%map second_pass_output_ledger, fully_applied =
          Sparse_ledger.apply_transaction_second_pass ~log second_pass_ledger
            partially_applied
        in
        ( `First_pass_target_ledger first_pass_output_ledger
        , `Second_passs_target_ledger second_pass_output_ledger
        , `Applied_transaction fully_applied ) )
  in
  ( match res with
  | Ok _ ->
      [%log info] "Successfully applied transaction out-of-snark"
  | Error err ->
      [%log error] "Failed to apply transaction out-of-snark"
        ~metadata:[ ("err", Error_json.error_to_yojson err) ] ) ;
  res

let debug_apply (witness : Transaction_witness.t) =
  debug_apply'
    ~protocol_state_view:(Protocol_state.Body.view witness.protocol_state_body)
    ~global_slot:witness.block_global_slot
    ~first_pass_ledger:witness.first_pass_ledger
    ~second_pass_ledger_opt:(Some witness.second_pass_ledger)
    witness.transaction

let debug_snark ~logger ~constraint_constants spec =
  [%log info] "Applying transaction in-snark" ;
  let channel = Out_channel.create snark_log in
  let dummy_sok_message =
    { Mina_base.Sok_message.fee = Currency.Fee.zero
    ; prover = Quickcheck.random_value Public_key.Compressed.gen
    }
  in
  let%bind worker_state =
    Snark_worker.Prod.Inputs.Worker_state.create
      ~proof_level:Genesis_constants.Proof_level.compiled ~constraint_constants
      ()
  in
  let%map res =
    Snark_worker.Prod.Inputs.perform_single worker_state
      ~log:(Mina_transaction_logic.Log.Channel channel)
      ~message:dummy_sok_message spec
  in
  Out_channel.close channel ;
  match res with
  | Ok _ ->
      [%log info] "Successfully applied transaction in-snark"
  | Error err ->
      [%log error] "Failed to apply transaction in-snark: $err"
        ~metadata:[ ("err", Error_json.error_to_yojson err) ]

let debug_spec ~logger ~constraint_constants
    (spec :
      (Transaction_witness.t, Ledger_proof.t) Snark_work_lib.Work.Single.Spec.t
      ) =
  match spec with
  | Transition (stmt, witness) ->
      (* TODO: test outputs against the snark statement *)
      let _ = stmt in
      let _ = debug_apply ~logger ~constraint_constants witness in
      debug_snark ~logger ~constraint_constants spec
  | Merge _ ->
      debug_snark ~logger ~constraint_constants spec

let run ~logger ~constraint_constants ~protocol_state_body ~ledger transaction =
  let protocol_state_view = Protocol_state.Body.view protocol_state_body in
  let global_slot =
    protocol_state_body |> Protocol_state.Body.consensus_state
    |> Consensus_state.curr_global_slot
  in
  let state_body_hash = Protocol_state.Body.hash protocol_state_body in
  let ( `First_pass_target_ledger first_pass_target_ledger
      , `Second_passs_target_ledger second_pass_target_ledger
      , `Applied_transaction _applied_transaction ) =
    debug_apply' ~logger ~constraint_constants ~protocol_state_view ~global_slot
      ~first_pass_ledger:ledger ~second_pass_ledger_opt:None transaction
    |> Or_error.ok_exn
  in
  let spec : _ Snark_work_lib.Work.Single.Spec.t =
    let stmt : Transaction_snark.Statement.t =
      { source =
          { first_pass_ledger = Sparse_ledger.merkle_root ledger
          ; second_pass_ledger =
              Sparse_ledger.merkle_root first_pass_target_ledger
          ; pending_coinbase_stack = Pending_coinbase.Stack.empty
          ; local_state = Mina_state.Local_state.dummy ()
          }
      ; target =
          { first_pass_ledger =
              Sparse_ledger.merkle_root first_pass_target_ledger
          ; second_pass_ledger =
              Sparse_ledger.merkle_root second_pass_target_ledger
          ; pending_coinbase_stack =
              Pending_coinbase.Stack.push_state state_body_hash global_slot
                Pending_coinbase.Stack.empty
          ; local_state = Mina_state.Local_state.dummy ()
          }
      ; connecting_ledger_left = Ledger_hash.empty_hash
      ; connecting_ledger_right = Ledger_hash.empty_hash
      ; supply_increase = Currency.Amount.Signed.zero
      ; fee_excess = Or_error.ok_exn (Transaction.fee_excess transaction)
      ; sok_digest = ()
      }
    in
    let witness : Transaction_witness.t =
      { transaction
      ; first_pass_ledger = ledger
      ; second_pass_ledger = first_pass_target_ledger
      ; protocol_state_body
      ; init_stack = Pending_coinbase.Stack.empty
      ; status = Transaction_status.Applied
      ; block_global_slot = global_slot
      }
    in
    Transition (stmt, witness)
  in
  debug_snark ~logger ~constraint_constants spec

let gen_2_party_ledger
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
  let keypairs = Lazy.force Key_gen.Sample_keypairs.keypairs in
  let keypair_a = keypairs.(0) in
  let keypair_b = keypairs.(1) in
  let ledger =
    Ledger.create_ephemeral ~depth:constraint_constants.ledger_depth ()
  in
  let account_a_id = Account_id.create (fst keypair_a) Token_id.default in
  let account_b_id = Account_id.create (fst keypair_b) Token_id.default in
  Ledger.create_new_account_exn ledger account_a_id
    (Account.create account_a_id
       (Currency.Balance.of_nanomina_int_exn 1_000_000_000) ) ;
  Ledger.create_new_account_exn ledger account_b_id
    (Account.create account_b_id
       (Currency.Balance.of_nanomina_int_exn 1_000_000_000) ) ;
  let sparse_ledger =
    Sparse_ledger.of_ledger_subset_exn ledger [ account_a_id; account_b_id ]
  in
  let staged_ledger = Staged_ledger.create_exn ~constraint_constants ~ledger in
  let wrap_keypair (_, sk) = Keypair.of_private_key_exn sk in
  ( `Ledger ledger
  , `Sparse_ledger sparse_ledger
  , `Staged_ledger staged_ledger
  , `Account_a (wrap_keypair keypair_a)
  , `Account_b (wrap_keypair keypair_b) )

let create_protocol_state ~(precomputed_values : Precomputed_values.t) ~ledger
    ~staged_ledger =
  Protocol_state.create_value ~previous_state_hash:State_hash.dummy
    ~genesis_state_hash:State_hash.dummy
    ~blockchain_state:
      (Blockchain_state.create_value
         ~staged_ledger_hash:(Staged_ledger.hash staged_ledger)
         ~genesis_ledger_hash:(Ledger.merkle_root ledger)
         ~timestamp:Block_time.zero
         ~body_reference:(Blake2.digest_string "BITSWAP-DISABLED")
         ~ledger_proof_statement:
           (Snarked_ledger_state.genesis
              ~genesis_ledger_hash:(Ledger.merkle_root ledger) ) )
    ~consensus_state:
      (Consensus.Data.Consensus_state.create_genesis
         ~negative_one_protocol_state_hash:State_hash.dummy
         ~genesis_ledger:(lazy ledger)
         ~genesis_epoch_data:None
         ~constraint_constants:precomputed_values.constraint_constants
         ~constants:precomputed_values.consensus_constants )
    ~constants:
      (Protocol_constants_checked.value_of_t
         precomputed_values.genesis_constants.protocol )

let create_user_command ~(sender : Keypair.t) ~(receiver : Keypair.t) =
  let payload =
    Signed_command.Payload.create
      ~fee:Mina_compile_config.minimum_user_command_fee
      ~fee_payer_pk:(Public_key.compress sender.public_key)
      ~nonce:Mina_numbers.Account_nonce.zero ~valid_until:None
      ~memo:Signed_command_memo.empty
      ~body:
        (Signed_command.Payload.Body.Payment
           { Payment_payload.Poly.source_pk =
               Public_key.compress sender.public_key
           ; receiver_pk = Public_key.compress receiver.public_key
           ; amount = Currency.Amount.of_nanomina_int_exn 100_000
           } )
  in
  Transaction.Command
    (User_command.Signed_command
       (Signed_command.forget_check @@ Signed_command.sign sender payload) )

let create_zkapp_payment ~(sender : Keypair.t) ~(receiver : Keypair.t) =
  let keymap =
    [ sender; receiver ]
    |> List.map ~f:(fun ({ public_key; private_key } : Keypair.t) ->
           (Public_key.compress public_key, private_key) )
    |> Public_key.Compressed.Map.of_alist_exn
  in
  let%map cmd =
    (*
    Zkapp_command_builder.mk_zkapp_command
      ~fee:(Int.of_string Mina_compile_config.minimum_user_command_fee_string)
      ~fee_payer_pk:sender_pk
      ~fee_payer_nonce:Account_nonce.zero
      [ { public_key = sender_pk
        ; token_id = Token_id.default
        ; update = Update.noop
        ; balance_change = Currency.Amount.Signed.of_nanomina_int_exn ~sgn:Sgn.Neg 100_000
        ; increment_nonce = false
        ; events = []
        ; actions = []
        ; call_data = Field.empty
        ; call_depth = 0
        ; preconditions = Preconditions.empty
        ; use_full_commitment = true
        ; implicit_account_creation_fee = false
        ; may_use_token = May_use_token.No
        ; authorization_kind = Authorization_kind.Signature
        }

      ]
      *)
    Zkapp_command_builder.(
      mk_forest
        [ mk_node
            (mk_account_update_body Signature No sender Token_id.default
               (-100_000) )
            []
        ; mk_node
            (mk_account_update_body None_given No receiver Token_id.default
               100_000 )
            []
        ]
      |> mk_zkapp_command
           ~fee:
             ( Unsigned.UInt64.to_int
             @@ Currency.Fee.to_uint64
                  Mina_compile_config.minimum_user_command_fee )
           ~fee_payer_pk:(Public_key.compress sender.public_key)
           ~fee_payer_nonce:Account_nonce.zero
      |> replace_authorizations ~keymap)
  in
  Transaction.Command (User_command.Zkapp_command cmd)

(*
  let open Zkapp_command in
  let memo = Signed_command_memo.empty in
  let fee_payer_body : Account_update.Body.Fee_payer.t =
    { public_key = sender_pk
    ; fee = Mina_compile_config.minimum_user_command_fee
    ; valid_until = None
    ; nonce = Account_nonce.zero }
  in
  let account_updates =
    let updates =
      []
    in
    Call_forest.of_account_updates updates
      ~account_update_depth:(fun (p : Account_update.Simple.t) ->
        p.body.call_depth )
    |> Call_forest.map ~f:Account_update.of_simple
    |> Call_forest.accumulate_hashes
         ~hash_account_update:(fun (p : Account_update.t) ->
           Zkapp_command.Digest.Account_update.create p )
  in
  let partial_commitment = Transaction_commitment.create ~account_updates_hash:(Call_forest.hash account_updates) in
  let full_commitment =
    Transaction_commitment.create_complete partial_commitment
      ~memo_hash:(Signed_command_memo.hash memo)
      ~fee_payer_hash:(Account_update.of_fee_payer {body = fee_payer_body; authorization = Signature.dummy} |> Digest.Account_update.create)
  in
  let cmd : Zkapp_command.t =
    { fee_payer =
      { body = fee_payer_body
      ; authorization = Signature_lib.Schnorr.Chunked.sign sender_sk full_transaction_commitment }
    ; account_updates
    ; memo }
  in
  Transaction.Command
    (User_command.Zkapp_command cmd)
*)
