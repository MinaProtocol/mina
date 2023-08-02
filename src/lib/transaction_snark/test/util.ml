open Core
open Currency
open Mina_base
open Signature_lib
module Tick = Snark_params.Tick
module Impl = Pickles.Impls.Step
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment
module Statement = Transaction_snark.Statement

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let genesis_constants = Genesis_constants.compiled

(* Always run tests with proof-level Full *)
let proof_level = Genesis_constants.Proof_level.Full

let consensus_constants =
  Consensus.Constants.create ~constraint_constants
    ~protocol_constants:genesis_constants.protocol

module Ledger = struct
  include Mina_ledger.Ledger

  let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
end

module Sparse_ledger = struct
  include Mina_ledger.Sparse_ledger

  let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
end

let ledger_depth = constraint_constants.ledger_depth

let snark_module =
  lazy
    ( module Transaction_snark.Make (struct
      let constraint_constants = constraint_constants

      let proof_level = proof_level
    end) : Transaction_snark.S )

let genesis_state_body =
  let compile_time_genesis =
    let open Staged_ledger_diff in
    (*not using Precomputed_values.for_unit_test because of dependency cycle*)
    Mina_state.Genesis_protocol_state.t
      ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
      ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
      ~constraint_constants ~consensus_constants ~genesis_body_reference
  in
  compile_time_genesis.data |> Mina_state.Protocol_state.body

let genesis_state_view = Mina_state.Protocol_state.Body.view genesis_state_body

let genesis_state_body_hash =
  Mina_state.Protocol_state.Body.hash genesis_state_body

let init_stack = Pending_coinbase.Stack.empty

let pending_coinbase_state_stack ~state_body_hash ~global_slot =
  { Transaction_snark.Pending_coinbase_stack_state.source = init_stack
  ; target =
      Pending_coinbase.Stack.push_state state_body_hash global_slot init_stack
  }

let trivial_zkapp =
  lazy
    (Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ())

type pass_number = Pass_1 | Pass_2

let pass_number_to_int = function Pass_1 -> 1 | Pass_2 -> 2

let check_zkapp_command_with_merges_exn ?signature_kind ?expected_failure
    ?ignore_outside_snark ?global_slot ?(state_body = genesis_state_body) ledger
    zkapp_commands =
  let module T = (val Lazy.force snark_module) in
  let ignore_outside_snark = Option.value ~default:false ignore_outside_snark in
  let state_view = Mina_state.Protocol_state.Body.view state_body in
  let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
  let global_slot =
    Option.value global_slot
      ~default:
        (Mina_numbers.Global_slot_since_genesis.succ
           state_view.global_slot_since_genesis )
  in
  let check_failure failure err =
    printf
      !"Expected failure %{sexp: Transaction_status.Failure.t} Got %s\n%!"
      failure (Error.to_string_hum err) ;
    assert (
      String.is_substring (Error.to_string_hum err)
        ~substring:(Transaction_status.Failure.to_string failure) )
  in
  with_return (fun { return } ->
      (* Do first pass, checking for expected error *)
      let partial_stmts =
        List.map zkapp_commands ~f:(fun zkapp_command ->
            let first_pass_ledger_witness =
              Sparse_ledger.of_ledger_subset_exn ledger
                (Zkapp_command.accounts_referenced zkapp_command)
            in
            let partial_stmt =
              match
                Ledger.apply_transaction_first_pass ~signature_kind
                  ~constraint_constants ~global_slot ~txn_state_view:state_view
                  ledger
                  (Mina_transaction.Transaction.Command
                     (Zkapp_command zkapp_command) )
              with
              | Error err -> (
                  match expected_failure with
                  | Some (failure, Pass_1) ->
                      check_failure failure err ;
                      (* got expected failure, let's go *)
                      return Async.Deferred.unit
                  | Some (failure, Pass_2) ->
                      failwithf
                        "apply_transaction_first_pass failed with %s, but \
                         expected %s on pass 2"
                        (Error.to_string_hum err)
                        (Transaction_status.Failure.to_string failure)
                        ()
                  | None ->
                      failwith
                        (sprintf "apply_transaction_first_pass failed with %s"
                           (Error.to_string_hum err) ) )
              | Ok stmt ->
                  stmt
            in
            (partial_stmt, first_pass_ledger_witness, Ledger.merkle_root ledger) )
      in
      let connecting_ledger = Ledger.merkle_root ledger in
      Async.Deferred.List.iter (List.zip_exn zkapp_commands partial_stmts)
        ~f:(fun
             ( zkapp_command
             , ( partial_stmt
               , first_pass_ledger_witness
               , first_pass_ledger_target_hash ) )
           ->
          match
            Or_error.try_with (fun () ->
                Transaction_snark.zkapp_command_witnesses_exn ?signature_kind
                  ~constraint_constants ~global_slot ~state_body
                  ~fee_excess:Amount.Signed.zero
                  [ ( `Pending_coinbase_init_stack init_stack
                    , `Pending_coinbase_of_statement
                        (pending_coinbase_state_stack ~state_body_hash
                           ~global_slot )
                    , `Sparse_ledger first_pass_ledger_witness
                    , `Ledger ledger
                    , `Connecting_ledger_hash connecting_ledger
                    , zkapp_command )
                  ] )
          with
          | Error err -> (
              match expected_failure with
              | Some (failure, Pass_2) ->
                  check_failure failure err ; Async.Deferred.unit
              | Some (failure, Pass_1) ->
                  failwithf
                    "zkapp_command_witnesses_exn failed with %s, but expected \
                     %s on pass 1"
                    (Error.to_string_hum err)
                    (Transaction_status.Failure.to_string failure)
                    ()
              | None ->
                  failwithf "zkapp_command_witnesses_exn failed with %s"
                    (Error.to_string_hum err) () )
          | Ok witnesses -> (
              let open Async.Deferred.Let_syntax in
              let applied, statement_opt =
                if ignore_outside_snark then
                  ( Ledger.Transaction_applied.Varying.Command
                      (Zkapp_command
                         { command =
                             { With_status.status = Applied
                             ; data = zkapp_command
                             }
                         ; accounts = []
                         ; new_accounts = []
                         } )
                  , None )
                else
                  let second_pass_ledger_source_hash =
                    Ledger.merkle_root ledger
                  in
                  let applied_txn =
                    Ledger.apply_transaction_second_pass ~signature_kind ledger
                      partial_stmt
                    |> Or_error.ok_exn
                  in
                  (*Expected transaction statement*)
                  let stmt : Transaction_snark.Statement.t =
                    { Mina_wire_types.Mina_state_snarked_ledger_state.Poly.V2
                      .source =
                        { first_pass_ledger =
                            Sparse_ledger.merkle_root first_pass_ledger_witness
                        ; second_pass_ledger = second_pass_ledger_source_hash
                        ; pending_coinbase_stack = init_stack
                        ; local_state = Mina_state.Local_state.empty ()
                        }
                    ; target =
                        { first_pass_ledger = first_pass_ledger_target_hash
                        ; second_pass_ledger = Ledger.merkle_root ledger
                        ; pending_coinbase_stack =
                            Pending_coinbase.Stack.push_state state_body_hash
                              global_slot init_stack
                        ; local_state = Mina_state.Local_state.empty ()
                        }
                    ; connecting_ledger_left = connecting_ledger
                    ; connecting_ledger_right = connecting_ledger
                    ; fee_excess = Zkapp_command.fee_excess zkapp_command
                    ; supply_increase =
                        Ledger.Transaction_applied.supply_increase applied_txn
                        |> Or_error.ok_exn
                    ; sok_digest = ()
                    }
                  in
                  (applied_txn.varying, Some stmt)
              in
              match applied with
              | Command (Zkapp_command { command; _ }) -> (
                  let run_in_snark () =
                    let%map p =
                      match List.rev witnesses with
                      | [] ->
                          failwith "no witnesses generated"
                      | (witness, spec, stmt) :: rest ->
                          let open Async.Deferred.Or_error.Let_syntax in
                          let%bind p1 =
                            Async.Deferred.Or_error.try_with ~here:[%here]
                              (fun () ->
                                T.of_zkapp_command_segment_exn ~statement:stmt
                                  ~witness ~spec )
                          in
                          Async.Deferred.List.fold ~init:(Ok p1) rest
                            ~f:(fun acc (witness, spec, stmt) ->
                              let%bind prev = Async.Deferred.return acc in
                              let%bind curr =
                                Async.Deferred.Or_error.try_with ~here:[%here]
                                  (fun () ->
                                    T.of_zkapp_command_segment_exn
                                      ~statement:stmt ~witness ~spec )
                              in
                              let sok_digest =
                                Sok_message.create ~fee:Fee.zero
                                  ~prover:
                                    (Quickcheck.random_value
                                       Public_key.Compressed.gen )
                                |> Sok_message.digest
                              in
                              T.merge ~sok_digest prev curr )
                    in
                    let p = Or_error.ok_exn p in
                    ( match statement_opt with
                    | Some expected_stmt ->
                        [%test_eq: Transaction_snark.Statement.t] expected_stmt
                          (Transaction_snark.statement p)
                    | None ->
                        () ) ;
                    if not ignore_outside_snark then
                      let target_ledger_root_snark =
                        (Transaction_snark.statement p).target
                          .second_pass_ledger
                      in
                      let target_ledger_root = Ledger.merkle_root ledger in
                      [%test_eq: Ledger_hash.t] target_ledger_root
                        target_ledger_root_snark
                  in
                  match command.status with
                  | Applied -> (
                      match expected_failure with
                      | Some (failure, pass) ->
                          failwith
                            (sprintf
                               !"Application did not fail as expected. \
                                 Expected failure: \
                                 %{sexp:Mina_base.Transaction_status.Failure.t} \
                                 on pass %d"
                               failure (pass_number_to_int pass) )
                      | None ->
                          run_in_snark () )
                  | Failed failure_tbl -> (
                      match expected_failure with
                      | None ->
                          failwith
                            (sprintf
                               !"Application failed. Failure statuses: %{sexp: \
                                 Mina_base.Transaction_status.Failure.Collection.t}"
                               failure_tbl )
                      | Some (failure, Pass_2) ->
                          let failures = List.concat failure_tbl in
                          assert (not (List.is_empty failures)) ;
                          let failed_as_expected =
                            (*Check that there's at least the expected failure*)
                            List.fold failures ~init:false ~f:(fun acc f ->
                                acc
                                || Mina_base.Transaction_status.Failure.(
                                     equal failure f) )
                          in
                          if not failed_as_expected then
                            failwithf
                              !"Application failed but not as expected. \
                                Expected failure: \
                                %{sexp:Mina_base.Transaction_status.Failure.t} \
                                Failure statuses: %{sexp: \
                                Mina_base.Transaction_status.Failure.Collection.t}"
                              failure failure_tbl ()
                          else run_in_snark ()
                      | Some (failure, Pass_1) ->
                          failwithf
                            !"Expected failure during pass 1, which did not \
                              occur: \
                              %{sexp:Mina_base.Transaction_status.Failure.t} \
                              Failure statuses during pass 2: %{sexp: \
                              Mina_base.Transaction_status.Failure.Collection.t}"
                            failure failure_tbl () ) )
              | _ ->
                  failwith "zkapp_command expected" ) ) )

let dummy_rule self : _ Pickles.Inductive_rule.t =
  let open Tick in
  { identifier = "dummy"
  ; prevs = [ self; self ]
  ; main =
      (fun { public_input = _ } ->
        let s =
          Run.exists Field.typ ~compute:(fun () -> Run.Field.Constant.zero)
        in
        let public_input =
          Run.exists Zkapp_statement.typ ~compute:(fun () -> assert false)
        in
        let proof =
          Run.exists (Typ.Internal.ref ()) ~compute:(fun () -> assert false)
        in
        Impl.run_checked (Transaction_snark.dummy_constraints ()) ;
        (* Unsatisfiable. *)
        Run.Field.(Assert.equal s (s + one)) ;
        { previous_proof_statements =
            [ { public_input; proof; proof_must_verify = Boolean.true_ }
            ; { public_input; proof; proof_must_verify = Boolean.true_ }
            ]
        ; public_output = ()
        ; auxiliary_output = ()
        } )
  ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
  }

let gen_snapp_ledger =
  let open Mina_transaction_logic.For_tests in
  let open Quickcheck.Generator.Let_syntax in
  let%bind test_spec = Test_spec.gen in
  let pks =
    Public_key.Compressed.Set.of_list
      (List.map (Array.to_list test_spec.init_ledger) ~f:(fun s ->
           Public_key.compress (fst s).public_key ) )
  in
  let%map kp =
    Quickcheck.Generator.filter Keypair.gen ~f:(fun kp ->
        not
          (Public_key.Compressed.Set.mem pks
             (Public_key.compress kp.public_key) ) )
  in
  (test_spec, kp)

let test_snapp_update ?expected_failure ?state_body ?snapp_permissions ~vk
    ~zkapp_prover test_spec ~init_ledger ~snapp_pk =
  let open Mina_transaction_logic.For_tests in
  Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
          (*create a snapp account*)
          Transaction_snark.For_tests.create_trivial_zkapp_account
            ?permissions:snapp_permissions ~vk ~ledger snapp_pk ;
          let open Async.Deferred.Let_syntax in
          let%bind zkapp_command =
            let zkapp_prover_and_vk = (zkapp_prover, vk) in
            Transaction_snark.For_tests.update_states ~zkapp_prover_and_vk
              ~constraint_constants test_spec
          in
          check_zkapp_command_with_merges_exn ?expected_failure ?state_body
            ledger [ zkapp_command ] ) )

let permissions_from_update (update : Account_update.Update.t) ~auth =
  let default = Permissions.user_default in
  { default with
    edit_state =
      ( if
        Zkapp_state.V.to_list update.app_state
        |> List.exists ~f:Zkapp_basic.Set_or_keep.is_set
      then auth
      else default.edit_state )
  ; set_delegate =
      ( if Zkapp_basic.Set_or_keep.is_keep update.delegate then
        default.set_delegate
      else auth )
  ; set_verification_key =
      ( if Zkapp_basic.Set_or_keep.is_keep update.verification_key then
        default.set_verification_key
      else auth )
  ; set_permissions =
      ( if Zkapp_basic.Set_or_keep.is_keep update.permissions then
        default.set_permissions
      else auth )
  ; set_zkapp_uri =
      ( if Zkapp_basic.Set_or_keep.is_keep update.zkapp_uri then
        default.set_zkapp_uri
      else auth )
  ; set_token_symbol =
      ( if Zkapp_basic.Set_or_keep.is_keep update.token_symbol then
        default.set_token_symbol
      else auth )
  ; set_voting_for =
      ( if Zkapp_basic.Set_or_keep.is_keep update.voting_for then
        default.set_voting_for
      else auth )
  ; set_timing =
      ( if Zkapp_basic.Set_or_keep.is_keep update.timing then default.set_timing
      else auth )
  }

module Wallet = struct
  type t = { private_key : Private_key.t; account : Account.t }

  let random_wallets ?(n = min (Int.pow 2 ledger_depth) (1 lsl 10)) () =
    let random_wallet () : t =
      let private_key = Private_key.create () in
      let public_key =
        Public_key.compress (Public_key.of_private_key_exn private_key)
      in
      let account_id = Account_id.create public_key Token_id.default in
      { private_key
      ; account =
          Account.create account_id
            (Balance.of_mina_int_exn (50 + Random.int 100))
      }
    in
    Array.init n ~f:(fun _ -> random_wallet ())

  let user_command ~fee_payer ~receiver_pk amt fee nonce memo =
    let payload : Signed_command.Payload.t =
      Signed_command.Payload.create ~fee
        ~fee_payer_pk:(Account.public_key fee_payer.account)
        ~nonce ~memo ~valid_until:None
        ~body:(Payment { receiver_pk; amount = Amount.of_nanomina_int_exn amt })
    in
    let signature = Signed_command.sign_payload fee_payer.private_key payload in
    Signed_command.check
      Signed_command.Poly.Stable.Latest.
        { payload
        ; signer = Public_key.of_private_key_exn fee_payer.private_key
        ; signature
        }
    |> Option.value_exn

  let stake_delegation ~fee_payer ~delegate_pk fee nonce memo =
    let payload : Signed_command.Payload.t =
      Signed_command.Payload.create ~fee
        ~fee_payer_pk:(Account.public_key fee_payer.account)
        ~nonce ~memo ~valid_until:None
        ~body:(Stake_delegation (Set_delegate { new_delegate = delegate_pk }))
    in
    let signature = Signed_command.sign_payload fee_payer.private_key payload in
    Signed_command.check
      Signed_command.Poly.Stable.Latest.
        { payload
        ; signer = Public_key.of_private_key_exn fee_payer.private_key
        ; signature
        }
    |> Option.value_exn

  let user_command_with_wallet wallets ~sender:i ~receiver:j amt fee nonce memo
      =
    let fee_payer = wallets.(i) in
    let receiver = wallets.(j) in
    user_command ~fee_payer
      ~receiver_pk:(Account.public_key receiver.account)
      amt fee nonce memo
end

(** Each transaction pushes the previous protocol state (used to validate
    the transaction) to the pending coinbase stack of protocol states*)
let pending_coinbase_state_update state_body_hash global_slot stack =
  Pending_coinbase.Stack.(push_state state_body_hash global_slot stack)

(** Push protocol state and coinbase if it is a coinbase transaction to the
      pending coinbase stacks (coinbase stack and state stack)*)
let pending_coinbase_stack_target (t : Mina_transaction.Transaction.Valid.t)
    state_body_hash global_slot stack =
  let stack_with_state =
    pending_coinbase_state_update state_body_hash global_slot stack
  in
  match t with
  | Coinbase c ->
      Pending_coinbase.(Stack.push_coinbase c stack_with_state)
  | _ ->
      stack_with_state

let check_balance pk balance ledger =
  let loc = Ledger.location_of_account ledger pk |> Option.value_exn in
  let acc = Ledger.get ledger loc |> Option.value_exn in
  [%test_eq: Balance.t] acc.balance (Balance.of_nanomina_int_exn balance)

(** Test legacy transactions*)
let test_transaction_union ?expected_failure ?txn_global_slot ledger txn =
  let open Mina_transaction in
  let to_preunion (t : Transaction.t) =
    match t with
    | Command (Signed_command x) ->
        `Transaction (Transaction.Command x)
    | Fee_transfer x ->
        `Transaction (Fee_transfer x)
    | Coinbase x ->
        `Transaction (Coinbase x)
    | Command (Zkapp_command x) ->
        `Zkapp_command x
  in
  let source_first_pass_ledger = Ledger.merkle_root ledger in
  let pending_coinbase_stack = Pending_coinbase.Stack.empty in
  let txn_unchecked = Transaction.forget txn in
  let state_body, state_body_hash =
    match txn_global_slot with
    | None ->
        (genesis_state_body, genesis_state_body_hash)
    | Some txn_global_slot ->
        let state_body =
          let state =
            (* NB: The [previous_state_hash] is a dummy, do not use. *)
            Mina_state.Protocol_state.create
              ~previous_state_hash:Snark_params.Tick0.Field.zero
              ~body:genesis_state_body
          in
          let consensus_state_at_slot =
            Consensus.Data.Consensus_state.Value.For_tests
            .with_global_slot_since_genesis
              (Mina_state.Protocol_state.consensus_state state)
              txn_global_slot
          in
          Mina_state.Protocol_state.(
            create_value
              ~previous_state_hash:(previous_state_hash state)
              ~genesis_state_hash:(genesis_state_hash state)
              ~blockchain_state:(blockchain_state state)
              ~consensus_state:consensus_state_at_slot
              ~constants:
                (Protocol_constants_checked.value_of_t
                   Genesis_constants.compiled.protocol ))
            .body
        in
        let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
        (state_body, state_body_hash)
  in
  let txn_state_view : Zkapp_precondition.Protocol_state.View.t =
    Mina_state.Protocol_state.Body.view state_body
  in
  let global_slot =
    Option.value txn_global_slot
      ~default:Mina_numbers.Global_slot_since_genesis.zero
  in
  let mentioned_keys, pending_coinbase_stack_target =
    let pending_coinbase_stack =
      Pending_coinbase.Stack.push_state state_body_hash global_slot
        pending_coinbase_stack
    in
    match txn_unchecked with
    | Command (Signed_command uc) ->
        ( Signed_command.accounts_referenced (uc :> Signed_command.t)
        , pending_coinbase_stack )
    | Command (Zkapp_command _) ->
        failwith "Zkapp_command commands not supported here"
    | Fee_transfer ft ->
        (Fee_transfer.receivers ft, pending_coinbase_stack)
    | Coinbase cb ->
        ( Coinbase.accounts_referenced cb
        , Pending_coinbase.Stack.push_coinbase cb pending_coinbase_stack )
  in
  let sok_signer =
    match to_preunion txn_unchecked with
    | `Transaction t ->
        (Transaction_union.of_transaction t).signer |> Public_key.compress
    | `Zkapp_command c ->
        Account_id.public_key (Zkapp_command.fee_payer c)
  in
  let sparse_ledger =
    Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
  in
  let expect_snark_failure, applied_transaction =
    match
      Result.( >>= )
        (Ledger.apply_transaction_first_pass ledger ~signature_kind:None
           ~constraint_constants ~global_slot ~txn_state_view txn_unchecked )
        (Ledger.apply_transaction_second_pass ~signature_kind:None ledger)
    with
    | Ok res ->
        ( if Option.is_some expected_failure then
          match Ledger.Transaction_applied.transaction_status res with
          | Applied ->
              failwith
                (sprintf "Expected Ledger.apply_transaction to fail with %s"
                   (Transaction_status.Failure.describe
                      (List.hd_exn (Option.value_exn expected_failure)) ) )
          | Failed f ->
              let got_expected_failure =
                List.equal Transaction_status.Failure.equal
                  (Option.value_exn expected_failure)
                  (List.concat f)
              in
              if not got_expected_failure then
                failwithf
                  !"Transaction failed unexpectedly: expected \
                    %{sexp:Mina_base.Transaction_status.Failure.t list}, got \
                    %{sexp:Mina_base.Transaction_status.Failure.t list}"
                  (Option.value_exn expected_failure)
                  (List.concat f) () ) ;
        (false, Some res)
    | Error e ->
        if Option.is_none expected_failure then
          failwith
            (sprintf "Ledger.apply_transaction failed with %s"
               (Error.to_string_hum e) )
        else if
          String.equal (Error.to_string_hum e)
            (Transaction_status.Failure.describe
               (List.hd_exn (Option.value_exn expected_failure)) )
        then ()
        else
          failwith
            (sprintf
               "Expected Ledger.apply_transaction to fail with %s but failed \
                with %s"
               (Transaction_status.Failure.describe
                  (List.hd_exn (Option.value_exn expected_failure)) )
               (Error.to_string_hum e) ) ;
        (true, None)
  in
  let target_first_pass_ledger = Ledger.merkle_root ledger in
  let sok_message = Sok_message.create ~fee:Fee.zero ~prover:sok_signer in
  let supply_increase =
    Option.value_map applied_transaction ~default:Amount.Signed.zero
      ~f:(fun txn ->
        Ledger.Transaction_applied.supply_increase txn |> Or_error.ok_exn )
  in
  match
    Or_error.try_with (fun () ->
        Transaction_snark.check_transaction ~constraint_constants ~sok_message
          ~source_first_pass_ledger ~target_first_pass_ledger
          ~init_stack:pending_coinbase_stack
          ~pending_coinbase_stack_state:
            { Transaction_snark.Pending_coinbase_stack_state.source =
                pending_coinbase_stack
            ; target = pending_coinbase_stack_target
            }
          ~supply_increase
          { transaction = txn; block_data = state_body; global_slot }
          (unstage @@ Sparse_ledger.handler sparse_ledger) )
  with
  | Error _e ->
      assert expect_snark_failure
  | Ok _ ->
      assert (not expect_snark_failure)

let test_zkapp_command ~signature_kind ?expected_failure
    ?(memo = Signed_command_memo.empty)
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
        Zkapps_examples.insert_signatures ~signature_kind pk_compressed sk
          zkapp_command )
  in
  Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
      let aux = initialize_ledger ledger in
      Async.Thread_safe.block_on_async_exn (fun () ->
          check_zkapp_command_with_merges_exn ?expected_failure ledger
            [ zkapp_command ] ) ;
      finalize_ledger aux ledger )
