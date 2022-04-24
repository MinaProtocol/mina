open Core
open Currency
open Mina_base
open Snark_params.Tick
open Signature_lib
module Impl = Pickles.Impls.Step
module Parties_segment = Transaction_snark.Parties_segment
module Statement = Transaction_snark.Statement

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let genesis_constants = Genesis_constants.compiled

let proof_level = Genesis_constants.Proof_level.compiled

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

module T = Transaction_snark.Make (struct
  let constraint_constants = constraint_constants

  let proof_level = proof_level
end)

let genesis_state_body =
  let compile_time_genesis =
    (*not using Precomputed_values.for_unit_test because of dependency cycle*)
    Mina_state.Genesis_protocol_state.t
      ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
      ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
      ~constraint_constants ~consensus_constants
  in
  compile_time_genesis.data |> Mina_state.Protocol_state.body

let genesis_state_body_hash =
  Mina_state.Protocol_state.Body.hash genesis_state_body

let init_stack = Pending_coinbase.Stack.empty

let pending_coinbase_state_stack ~state_body_hash =
  { Transaction_snark.Pending_coinbase_stack_state.source = init_stack
  ; target = Pending_coinbase.Stack.push_state state_body_hash init_stack
  }

let apply_parties ledger parties =
  let parties =
    match parties with
    | [] ->
        []
    | [ ps ] ->
        [ ( `Pending_coinbase_init_stack init_stack
          , `Pending_coinbase_of_statement
              (pending_coinbase_state_stack
                 ~state_body_hash:genesis_state_body_hash)
          , ps )
        ]
    | ps1 :: ps2 :: rest ->
        let ps1 =
          ( `Pending_coinbase_init_stack init_stack
          , `Pending_coinbase_of_statement
              (pending_coinbase_state_stack
                 ~state_body_hash:genesis_state_body_hash)
          , ps1 )
        in
        let pending_coinbase_state_stack =
          pending_coinbase_state_stack ~state_body_hash:genesis_state_body_hash
        in
        let unchanged_stack_state ps =
          ( `Pending_coinbase_init_stack init_stack
          , `Pending_coinbase_of_statement
              { pending_coinbase_state_stack with
                source = pending_coinbase_state_stack.target
              }
          , ps )
        in
        let ps2 = unchanged_stack_state ps2 in
        ps1 :: ps2 :: List.map rest ~f:unchanged_stack_state
  in
  let witnesses =
    Transaction_snark.parties_witnesses_exn ~constraint_constants
      ~state_body:genesis_state_body ~fee_excess:Amount.Signed.zero
      (`Ledger ledger) parties
  in
  let open Impl in
  List.iter witnesses ~f:(fun (witness, spec, statement, snapp_stmt) ->
      run_and_check (fun () ->
          let s =
            exists Statement.With_sok.typ ~compute:(fun () -> statement)
          in
          let snapp_stmt =
            Option.value_map ~default:[] snapp_stmt ~f:(fun (i, stmt) ->
                [ (i, exists Zkapp_statement.typ ~compute:(fun () -> stmt)) ])
          in
          Transaction_snark.Base.Parties_snark.main ~constraint_constants
            (Parties_segment.Basic.to_single_list spec)
            snapp_stmt s ~witness ;
          fun () -> ())
      |> Or_error.ok_exn)

let trivial_snapp =
  lazy
    (Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ())

let check_parties_with_merges_exn ?(state_body = genesis_state_body)
    ?(apply = true) ledger partiess =
  (*TODO: merge multiple snapp transactions*)
  let state_view = Mina_state.Protocol_state.Body.view state_body in
  let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
  Async.Deferred.List.iter partiess ~f:(fun parties ->
      if apply then (
        let new_mask = Ledger.Mask.create ~depth:(Ledger.depth ledger) () in
        let new_ledger = Ledger.register_mask ledger new_mask in
        let _applied =
          Ledger.apply_parties_unchecked ~constraint_constants ~state_view
            new_ledger parties
          |> Or_error.ok_exn
        in
        let _a = Ledger.unregister_mask_exn ~loc:__LOC__ new_ledger in
        match (fst _applied).command.status with
        | Transaction_status.Applied _ ->
            Core.printf "Ledger.apply_parties_unchecked successful\n%!" ;
            ()
        | Failed (tbl, _) ->
            Core.printf "Ledger.apply_parties_unchecked failed with %s\n%!"
              ( Transaction_status.Failure.Collection.to_yojson tbl
              |> Yojson.Safe.to_string ) ;
            () )
      else () ;
      Core.printf !"starting sparse ledger application\n%!" ;
      let witnesses =
        match
          Or_error.try_with (fun () ->
              Transaction_snark.parties_witnesses_exn ~constraint_constants
                ~state_body ~fee_excess:Amount.Signed.zero (`Ledger ledger)
                [ ( `Pending_coinbase_init_stack init_stack
                  , `Pending_coinbase_of_statement
                      (pending_coinbase_state_stack ~state_body_hash)
                  , parties )
                ])
        with
        | Ok a ->
            a
        | Error e ->
            failwith
              (sprintf "parties_witnesses_exn failed with %s"
                 (Error.to_string_hum e))
      in
      let print_statement spec stmt witness =
        Core.printf
          !"spec: %s statement: %s witness: %s\n%!"
          ( Transaction_snark.Parties_segment.Basic.to_yojson spec
          |> Yojson.Safe.to_string )
          ( Transaction_snark.Statement.With_sok.to_yojson stmt
          |> Yojson.Safe.to_string )
          ( Transaction_snark.Parties_segment.Witness.to_yojson witness
          |> Yojson.Safe.to_string )
      in
      let _deferred_or_error d = Async.Deferred.map d ~f:(fun p -> Ok p) in
      let open Async.Deferred.Let_syntax in
      let%map p =
        match List.rev witnesses with
        | [] ->
            failwith "no witnesses generated"
        | (witness, spec, stmt, snapp_statement) :: rest ->
            let open Async.Deferred.Or_error.Let_syntax in
            print_statement spec stmt witness ;
            let%bind p1 =
              Async.Deferred.Or_error.try_with (fun () ->
                  T.of_parties_segment_exn ~statement:stmt ~witness ~spec
                    ~snapp_statement)
            in
            Async.Deferred.List.fold ~init:(Ok p1) rest
              ~f:(fun acc (witness, spec, stmt, snapp_statement) ->
                print_statement spec stmt witness ;
                let%bind prev = Async.Deferred.return acc in
                let%bind curr =
                  Async.Deferred.Or_error.try_with (fun () ->
                      T.of_parties_segment_exn ~statement:stmt ~witness ~spec
                        ~snapp_statement)
                in
                let sok_digest =
                  Sok_message.create ~fee:Fee.zero
                    ~prover:(Quickcheck.random_value Public_key.Compressed.gen)
                  |> Sok_message.digest
                in
                T.merge ~sok_digest prev curr)
      in
      let _p = Or_error.ok_exn p in
      ())

let dummy_rule self : _ Pickles.Inductive_rule.t =
  { identifier = "dummy"
  ; prevs = [ self; self ]
  ; main_value = (fun [ _; _ ] _ -> [ true; true ])
  ; main =
      (fun [ _; _ ] _ ->
        Transaction_snark.dummy_constraints ()
        |> Snark_params.Tick.Run.run_checked
        |> fun () ->
        (* Unsatisfiable. *)
        Run.exists Field.typ ~compute:(fun () -> Run.Field.Constant.zero)
        |> fun s ->
        Run.Field.(Assert.equal s (s + one))
        |> fun () :
               (Zkapp_statement.Checked.t * (Zkapp_statement.Checked.t * unit))
               Pickles_types.Hlist0.H1
                 (Pickles_types.Hlist.E01(Pickles.Inductive_rule.B))
               .t ->
        [ Boolean.true_; Boolean.true_ ])
  }

let gen_snapp_ledger =
  let open Mina_transaction_logic.For_tests in
  let open Quickcheck.Generator.Let_syntax in
  let%bind test_spec = Test_spec.gen in
  let pks =
    Public_key.Compressed.Set.of_list
      (List.map (Array.to_list test_spec.init_ledger) ~f:(fun s ->
           Public_key.compress (fst s).public_key))
  in
  let%map kp =
    Quickcheck.Generator.filter Keypair.gen ~f:(fun kp ->
        not
          (Public_key.Compressed.Set.mem pks
             (Public_key.compress kp.public_key)))
  in
  (test_spec, kp)

let test_snapp_update ?snapp_permissions ?state_body ~vk ~snapp_prover test_spec
    ~init_ledger ~snapp_pk =
  let open Mina_transaction_logic.For_tests in
  Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
      Async.Thread_safe.block_on_async_exn (fun () ->
          Init_ledger.init (module Ledger.Ledger_inner) init_ledger ledger ;
          (*create a snapp account*)
          Transaction_snark.For_tests.create_trivial_zkapp_account
            ?permissions:snapp_permissions ~vk ~ledger snapp_pk ;
          let open Async.Deferred.Let_syntax in
          let%bind parties =
            Transaction_snark.For_tests.update_states ~snapp_prover
              ~constraint_constants test_spec
          in
          Core.printf "Parties %s\n%!"
            (Parties.to_yojson parties |> Yojson.Safe.to_string) ;
          check_parties_with_merges_exn ?state_body ledger [ parties ]))

let permissions_from_update (update : Party.Update.t) ~auth =
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
            (Balance.of_int ((50 + Random.int 100) * 1_000_000_000))
      }
    in
    Array.init n ~f:(fun _ -> random_wallet ())

  let user_command ~fee_payer ~source_pk ~receiver_pk amt fee nonce memo =
    let payload : Signed_command.Payload.t =
      Signed_command.Payload.create ~fee
        ~fee_payer_pk:(Account.public_key fee_payer.account)
        ~nonce ~memo ~valid_until:None
        ~body:(Payment { source_pk; receiver_pk; amount = Amount.of_int amt })
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
      ~source_pk:(Account.public_key fee_payer.account)
      ~receiver_pk:(Account.public_key receiver.account)
      amt fee nonce memo
end

(** Each transaction pushes the previous protocol state (used to validate
    the transaction) to the pending coinbase stack of protocol states*)
let pending_coinbase_state_update state_body_hash stack =
  Pending_coinbase.Stack.(push_state state_body_hash stack)

(** Push protocol state and coinbase if it is a coinbase transaction to the
      pending coinbase stacks (coinbase stack and state stack)*)
let pending_coinbase_stack_target (t : Mina_transaction.Transaction.Valid.t)
    state_body_hash stack =
  let stack_with_state = pending_coinbase_state_update state_body_hash stack in
  match t with
  | Coinbase c ->
      Pending_coinbase.(Stack.push_coinbase c stack_with_state)
  | _ ->
      stack_with_state

let check_balance pk balance ledger =
  let loc = Ledger.location_of_account ledger pk |> Option.value_exn in
  let acc = Ledger.get ledger loc |> Option.value_exn in
  [%test_eq: Balance.t] acc.balance (Balance.of_int balance)
