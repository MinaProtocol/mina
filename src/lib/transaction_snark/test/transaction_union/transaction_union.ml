open Core
open Mina_ledger
open Currency
open Signature_lib
open Mina_transaction
module U = Transaction_snark_tests.Util
open Mina_base

let state_body = U.genesis_state_body

let constraint_constants = U.constraint_constants

let consensus_constants = U.consensus_constants

let ledger_depth = U.ledger_depth

let state_body_hash = U.genesis_state_body_hash

let%test_module "Transaction union tests" =
  ( module struct
    (* For tests let's just monkey patch ledger and sparse ledger to freeze their
     * ledger_hashes. The nominal type is just so we don't mix this up in our
     * real code. *)
    module Ledger = struct
      include Ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t

      let merkle_root_after_user_command_exn t ~txn_global_slot txn =
        let hash =
          merkle_root_after_user_command_exn
            ~constraint_constants:U.constraint_constants ~txn_global_slot t txn
        in
        Frozen_ledger_hash.of_ledger_hash hash
    end

    module Sparse_ledger = struct
      include Sparse_ledger

      let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
    end

    let of_user_command' (sok_digest : Sok_message.Digest.t) ledger
        (user_command : Signed_command.With_valid_signature.t) init_stack
        pending_coinbase_stack_state state_body handler =
      let module T = (val Lazy.force U.snark_module) in
      let source = Ledger.merkle_root ledger in
      let current_global_slot =
        Mina_state.Protocol_state.Body.consensus_state state_body
        |> Consensus.Data.Consensus_state.global_slot_since_genesis
      in
      let target =
        Ledger.merkle_root_after_user_command_exn ledger
          ~txn_global_slot:current_global_slot user_command
      in
      let user_command_in_block =
        { Transaction_protocol_state.Poly.transaction = user_command
        ; block_data = state_body
        }
      in
      let user_command_supply_increase = Currency.Amount.Signed.zero in
      Async.Thread_safe.block_on_async_exn (fun () ->
          let statement =
            let txn =
              Transaction.Command
                (User_command.Signed_command
                   (Signed_command.forget_check user_command) )
            in
            Transaction_snark.Statement.Poly.with_empty_local_state ~source
              ~target ~sok_digest
              ~fee_excess:(Or_error.ok_exn (Transaction.fee_excess txn))
              ~supply_increase:user_command_supply_increase
              ~pending_coinbase_stack_state
          in
          T.of_user_command ~init_stack ~statement user_command_in_block handler )

    let coinbase_test state_body ~carryforward =
      let mk_pubkey () =
        Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let state_body_hash = Mina_state.Protocol_state.Body.hash state_body in
      let producer = mk_pubkey () in
      let producer_id = Account_id.create producer Token_id.default in
      let receiver = mk_pubkey () in
      let receiver_id = Account_id.create receiver Token_id.default in
      let other = mk_pubkey () in
      let other_id = Account_id.create other Token_id.default in
      let pending_coinbase_init = Pending_coinbase.Stack.empty in
      let cb =
        Coinbase.create
          ~amount:(Currency.Amount.of_mina_int_exn 10)
          ~receiver
          ~fee_transfer:
            (Some
               (Coinbase.Fee_transfer.create ~receiver_pk:other
                  ~fee:U.constraint_constants.account_creation_fee ) )
        |> Or_error.ok_exn
      in
      let transaction = Mina_transaction.Transaction.Coinbase cb in
      let source_stack =
        if carryforward then
          Pending_coinbase.Stack.(
            push_state state_body_hash pending_coinbase_init)
        else pending_coinbase_init
      in
      let pending_coinbase_stack_target =
        U.pending_coinbase_stack_target transaction U.genesis_state_body_hash
          pending_coinbase_init
      in
      let txn_in_block =
        { Transaction_protocol_state.Poly.transaction; block_data = state_body }
      in
      Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
          Ledger.create_new_account_exn ledger producer_id
            (Account.create receiver_id Balance.zero) ;
          let sparse_ledger =
            Sparse_ledger.of_ledger_subset_exn ledger
              [ producer_id; receiver_id; other_id ]
          in
          let sparse_ledger_after, applied_transaction =
            Sparse_ledger.apply_transaction
              ~constraint_constants:U.constraint_constants sparse_ledger
              ~txn_state_view:
                (txn_in_block.block_data |> Mina_state.Protocol_state.Body.view)
              txn_in_block.transaction
            |> Or_error.ok_exn
          in
          let supply_increase =
            Mina_ledger.Ledger.Transaction_applied.supply_increase
              applied_transaction
            |> Or_error.ok_exn
          in
          Transaction_snark.check_transaction txn_in_block
            (unstage (Sparse_ledger.handler sparse_ledger))
            ~constraint_constants:U.constraint_constants
            ~sok_message:
              (Mina_base.Sok_message.create ~fee:Currency.Fee.zero
                 ~prover:Public_key.Compressed.empty )
            ~source:(Sparse_ledger.merkle_root sparse_ledger)
            ~target:(Sparse_ledger.merkle_root sparse_ledger_after)
            ~init_stack:pending_coinbase_init
            ~pending_coinbase_stack_state:
              { source = source_stack; target = pending_coinbase_stack_target }
            ~zkapp_account1:None ~zkapp_account2:None ~supply_increase )

    let%test_unit "coinbase with new state body hash" =
      Test_util.with_randomness 123456789 (fun () ->
          coinbase_test state_body ~carryforward:false )

    let%test_unit "coinbase with carry-forward state body hash" =
      Test_util.with_randomness 123456789 (fun () ->
          coinbase_test state_body ~carryforward:true )

    let%test_unit "new_account" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = U.Wallet.random_wallets () in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              Array.iter
                (Array.sub wallets ~pos:1 ~len:(Array.length wallets - 1))
                ~f:(fun { account; _ } ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              let t1 =
                U.Wallet.user_command_with_wallet wallets ~sender:1 ~receiver:0
                  8_000_000_000
                  (Fee.of_mina_int_exn @@ Random.int 20)
                  Account.Nonce.zero
                  (Signed_command_memo.create_by_digesting_string_exn
                     (Test_util.arbitrary_string
                        ~len:Signed_command_memo.max_digestible_string_length ) )
              in
              let current_global_slot =
                Mina_state.Protocol_state.Body.consensus_state state_body
                |> Consensus.Data.Consensus_state.global_slot_since_genesis
              in
              let target =
                Ledger.merkle_root_after_user_command_exn ledger
                  ~txn_global_slot:current_global_slot t1
              in
              let mentioned_keys =
                Signed_command.accounts_referenced
                  (Signed_command.forget_check t1)
              in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger mentioned_keys
              in
              let sok_message =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(1).account.public_key
              in
              let pending_coinbase_stack = Pending_coinbase.Stack.empty in
              let pending_coinbase_stack_target =
                U.pending_coinbase_stack_target (Command (Signed_command t1))
                  state_body_hash pending_coinbase_stack
              in
              let pending_coinbase_stack_state =
                { Transaction_snark.Pending_coinbase_stack_state.source =
                    pending_coinbase_stack
                ; target = pending_coinbase_stack_target
                }
              in
              let user_command_supply_increase =
                (* receiver account is created, decrease supply by account creation fee *)
                let magnitude =
                  U.constraint_constants.account_creation_fee
                  |> Currency.Amount.of_fee
                in
                Currency.Amount.Signed.create ~magnitude ~sgn:Sgn.Neg
              in
              Transaction_snark.check_user_command ~constraint_constants
                ~sok_message
                ~source:(Ledger.merkle_root ledger)
                ~target ~init_stack:pending_coinbase_stack
                ~pending_coinbase_stack_state
                ~supply_increase:user_command_supply_increase
                { transaction = t1; block_data = state_body }
                (unstage @@ Sparse_ledger.handler sparse_ledger) ) )

    let account_fee =
      Fee.to_nanomina_int constraint_constants.account_creation_fee

    let%test_unit "account creation fee - user commands" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = U.Wallet.random_wallets ~n:3 () |> Array.to_list in
          let sender = List.hd_exn wallets in
          let receivers = List.tl_exn wallets in
          let txns_per_receiver = 2 in
          let amount = 8_000_000_000 in
          let txn_fee = 2_000_000_000 in
          let memo =
            Signed_command_memo.create_by_digesting_string_exn
              (Test_util.arbitrary_string
                 ~len:Signed_command_memo.max_digestible_string_length )
          in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let _, ucs =
                let receivers =
                  List.fold ~init:receivers
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receivers @ acc)
                in
                List.fold receivers ~init:(Account.Nonce.zero, [])
                  ~f:(fun (nonce, txns) receiver ->
                    let uc =
                      U.Wallet.user_command ~fee_payer:sender
                        ~receiver_pk:(Account.public_key receiver.account)
                        amount
                        (Fee.of_nanomina_int_exn txn_fee)
                        nonce memo
                    in
                    (Account.Nonce.succ nonce, txns @ [ uc ]) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier sender.account)
                sender.account ;
              let () =
                List.iter ucs ~f:(fun uc ->
                    U.test_transaction_union ledger
                      (Transaction.Command (Signed_command uc)) )
              in
              List.iter receivers ~f:(fun receiver ->
                  U.check_balance
                    (Account.identifier receiver.account)
                    ((amount * txns_per_receiver) - account_fee)
                    ledger ) ;
              U.check_balance
                (Account.identifier sender.account)
                ( Balance.to_nanomina_int sender.account.balance
                - (amount + txn_fee) * txns_per_receiver * List.length receivers
                )
                ledger ) )

    let%test_unit "account creation fee - fee transfers" =
      Test_util.with_randomness 123456789 (fun () ->
          let receivers = U.Wallet.random_wallets ~n:3 () |> Array.to_list in
          let txns_per_receiver = 3 in
          let fee = 8_000_000_000 in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let fts =
                let receivers =
                  List.fold ~init:receivers
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receivers @ acc)
                  |> One_or_two.group_list
                in
                List.fold receivers ~init:[] ~f:(fun txns receiver ->
                    let ft : Fee_transfer.t =
                      Or_error.ok_exn @@ Fee_transfer.of_singles
                      @@ One_or_two.map receiver ~f:(fun receiver ->
                             Fee_transfer.Single.create
                               ~receiver_pk:receiver.account.public_key
                               ~fee:(Currency.Fee.of_nanomina_int_exn fee)
                               ~fee_token:receiver.account.token_id )
                    in
                    txns @ [ ft ] )
              in
              let () =
                List.iter fts ~f:(fun ft ->
                    let txn = Mina_transaction.Transaction.Fee_transfer ft in
                    U.test_transaction_union ledger txn )
              in
              List.iter receivers ~f:(fun receiver ->
                  U.check_balance
                    (Account.identifier receiver.account)
                    ((fee * txns_per_receiver) - account_fee)
                    ledger ) ) )

    let%test_unit "account creation fee - coinbase" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = U.Wallet.random_wallets ~n:3 () in
          let receiver = wallets.(0) in
          let other = wallets.(1) in
          let dummy_account = wallets.(2) in
          let reward = 10_000_000_000 in
          let fee =
            Fee.to_nanomina_int constraint_constants.account_creation_fee
          in
          let coinbase_count = 3 in
          let ft_count = 2 in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let _, cbs =
                let fts =
                  List.map (List.init ft_count ~f:Fn.id) ~f:(fun _ ->
                      Coinbase.Fee_transfer.create
                        ~receiver_pk:other.account.public_key
                        ~fee:constraint_constants.account_creation_fee )
                in
                List.fold ~init:(fts, []) (List.init coinbase_count ~f:Fn.id)
                  ~f:(fun (fts, cbs) _ ->
                    let cb =
                      Coinbase.create
                        ~amount:(Currency.Amount.of_nanomina_int_exn reward)
                        ~receiver:receiver.account.public_key
                        ~fee_transfer:(List.hd fts)
                      |> Or_error.ok_exn
                    in
                    (Option.value ~default:[] (List.tl fts), cb :: cbs) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier dummy_account.account)
                dummy_account.account ;
              let () =
                List.iter cbs ~f:(fun cb ->
                    let txn = Mina_transaction.Transaction.Coinbase cb in
                    U.test_transaction_union ledger txn )
              in
              let fees = fee * ft_count in
              U.check_balance
                (Account.identifier receiver.account)
                ((reward * coinbase_count) - account_fee - fees)
                ledger ;
              U.check_balance
                (Account.identifier other.account)
                (fees - account_fee) ledger ) )

    module Pc_with_init_stack = struct
      type t =
        { pc : Transaction_snark.Pending_coinbase_stack_state.t
        ; init_stack : Pending_coinbase.Stack.t
        }
    end

    let test_base_and_merge ~state_hash_and_body1 ~state_hash_and_body2
        ~carryforward1 ~carryforward2 =
      let module T = (val Lazy.force U.snark_module) in
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = U.Wallet.random_wallets () in
          (*let state_body = Lazy.force state_body in
            let state_body_hash = Lazy.force state_body_hash in*)
          let state_body_hash1, state_body1 = state_hash_and_body1 in
          let state_body_hash2, state_body2 = state_hash_and_body2 in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              Array.iter wallets ~f:(fun { account; private_key = _ } ->
                  Ledger.create_new_account_exn ledger
                    (Account.identifier account)
                    account ) ;
              let memo =
                Signed_command_memo.create_by_digesting_string_exn
                  (Test_util.arbitrary_string
                     ~len:Signed_command_memo.max_digestible_string_length )
              in
              let t1 =
                U.Wallet.user_command_with_wallet wallets ~sender:0 ~receiver:1
                  8_000_000_000
                  (Fee.of_mina_int_exn @@ Random.int 20)
                  Account.Nonce.zero memo
              in
              let t2 =
                U.Wallet.user_command_with_wallet wallets ~sender:1 ~receiver:2
                  8_000_000_000
                  (Fee.of_mina_int_exn @@ Random.int 20)
                  Account.Nonce.zero memo
              in
              let sok_digest =
                Sok_message.create ~fee:Fee.zero
                  ~prover:wallets.(0).account.public_key
                |> Sok_message.digest
              in
              let sparse_ledger =
                Sparse_ledger.of_ledger_subset_exn ledger
                  (List.concat_map
                     ~f:(fun t ->
                       (* NB: Shouldn't assume the same next_available_token
                          for each command normally, but we know statically
                          that these are payments in this test.
                       *)
                       Signed_command.accounts_referenced
                         (Signed_command.forget_check t) )
                     [ t1; t2 ] )
              in
              let init_stack1 = Pending_coinbase.Stack.empty in
              let pending_coinbase_stack_state1 =
                (* No coinbase to add to the stack. *)
                let stack_with_state =
                  Pending_coinbase.Stack.push_state state_body_hash1 init_stack1
                in
                (* Since protocol state body is added once per block, the
                   source would already have the state if [carryforward=true]
                   from the previous transaction in the sequence of
                   transactions in a block. We add state to [init_stack] and
                   then check that it is equal to the target.
                *)
                let source_stack, target_stack =
                  if carryforward1 then (stack_with_state, stack_with_state)
                  else (init_stack1, stack_with_state)
                in
                { Pc_with_init_stack.pc =
                    { source = source_stack; target = target_stack }
                ; init_stack = init_stack1
                }
              in
              let proof12 =
                of_user_command' sok_digest ledger t1
                  pending_coinbase_stack_state1.init_stack
                  pending_coinbase_stack_state1.pc state_body1
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let current_global_slot =
                Mina_state.Protocol_state.Body.consensus_state state_body1
                |> Consensus.Data.Consensus_state.global_slot_since_genesis
              in
              let sparse_ledger, _ =
                Sparse_ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:current_global_slot sparse_ledger t1
                |> Or_error.ok_exn
              in
              let pending_coinbase_stack_state2, state_body2 =
                let previous_stack = pending_coinbase_stack_state1.pc.target in
                let stack_with_state2 =
                  Pending_coinbase.Stack.(
                    push_state state_body_hash2 previous_stack)
                in
                (* No coinbase to add. *)
                let source_stack, target_stack, init_stack, state_body2 =
                  if carryforward2 then
                    (* Source and target already have the protocol state,
                       init_stack will be such that
                       [init_stack + state_body_hash1 = target = source].
                    *)
                    (previous_stack, previous_stack, init_stack1, state_body1)
                  else
                    (* Add the new state such that
                       [previous_stack + state_body_hash2
                        = init_stack + state_body_hash2
                        = target].
                    *)
                    ( previous_stack
                    , stack_with_state2
                    , previous_stack
                    , state_body2 )
                in
                ( { Pc_with_init_stack.pc =
                      { source = source_stack; target = target_stack }
                  ; init_stack
                  }
                , state_body2 )
              in
              ignore
                ( Ledger.apply_user_command ~constraint_constants ledger
                    ~txn_global_slot:current_global_slot t1
                  |> Or_error.ok_exn
                  : Ledger.Transaction_applied.Signed_command_applied.t ) ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof23 =
                of_user_command' sok_digest ledger t2
                  pending_coinbase_stack_state2.init_stack
                  pending_coinbase_stack_state2.pc state_body2
                  (unstage @@ Sparse_ledger.handler sparse_ledger)
              in
              let current_global_slot =
                Mina_state.Protocol_state.Body.consensus_state state_body2
                |> Consensus.Data.Consensus_state.global_slot_since_genesis
              in
              let sparse_ledger, _ =
                Sparse_ledger.apply_user_command ~constraint_constants
                  ~txn_global_slot:current_global_slot sparse_ledger t2
                |> Or_error.ok_exn
              in
              ignore
                ( Ledger.apply_user_command ledger ~constraint_constants
                    ~txn_global_slot:current_global_slot t2
                  |> Or_error.ok_exn
                  : Mina_transaction_logic.Transaction_applied
                    .Signed_command_applied
                    .t ) ;
              [%test_eq: Frozen_ledger_hash.t]
                (Ledger.merkle_root ledger)
                (Sparse_ledger.merkle_root sparse_ledger) ;
              let proof13 =
                Async.Thread_safe.block_on_async_exn (fun () ->
                    T.merge ~sok_digest proof12 proof23 )
                |> Or_error.ok_exn
              in
              Async.Thread_safe.block_on_async (fun () ->
                  T.verify_against_digest proof13 )
              |> Result.ok_exn ) )

    let%test "base_and_merge: transactions in one block (t1,t2 in b1), \
              carryforward the state from a previous transaction t0 in b1" =
      let state_hash_and_body1 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1
        ~state_hash_and_body2:state_hash_and_body1 ~carryforward1:true
        ~carryforward2:true

    (* No new state body, carryforward the stack from the previous transaction*)

    let%test "base_and_merge: transactions in one block (t1,t2 in b1), don't \
              carryforward the state from a previous transaction t0 in b1" =
      let state_hash_and_body1 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1
        ~state_hash_and_body2:state_hash_and_body1 ~carryforward1:false
        ~carryforward2:true

    let%test "base_and_merge: transactions in two different blocks (t1,t2 in \
              b1, b2 resp.), carryforward the state from a previous \
              transaction t0 in b1" =
      let state_hash_and_body1 =
        let open Staged_ledger_diff in
        let state_body0 =
          Mina_state.Protocol_state.negative_one
            ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
            ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
            ~constraint_constants ~consensus_constants ~genesis_body_reference
          |> Mina_state.Protocol_state.body
        in
        let state_body_hash0 =
          Mina_state.Protocol_state.Body.hash state_body0
        in
        (state_body_hash0, state_body0)
      in
      let state_hash_and_body2 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1 ~state_hash_and_body2
        ~carryforward1:true ~carryforward2:false

    (*t2 is in a new state, therefore do not carryforward the previous state*)

    let%test "base_and_merge: transactions in two different blocks (t1,t2 in \
              b1, b2 resp.), don't carryforward the state from a previous \
              transaction t0 in b1" =
      let state_hash_and_body1 =
        let state_body0 =
          let open Staged_ledger_diff in
          Mina_state.Protocol_state.negative_one
            ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
            ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
            ~constraint_constants ~consensus_constants ~genesis_body_reference
          |> Mina_state.Protocol_state.body
        in
        let state_body_hash0 =
          Mina_state.Protocol_state.Body.hash state_body0
        in
        (state_body_hash0, state_body0)
      in
      let state_hash_and_body2 = (state_body_hash, state_body) in
      test_base_and_merge ~state_hash_and_body1 ~state_hash_and_body2
        ~carryforward1:false ~carryforward2:false

    let create_account pk token balance =
      Account.create
        (Account_id.create pk token)
        (Balance.of_nanomina_int_exn balance)

    let test_user_command_with_accounts ~ledger ~accounts ~signer ~fee
        ~fee_payer_pk ~fee_token ?memo ?valid_until ?nonce body =
      let memo =
        match memo with
        | Some memo ->
            memo
        | None ->
            Signed_command_memo.create_by_digesting_string_exn
              (Test_util.arbitrary_string
                 ~len:Signed_command_memo.max_digestible_string_length )
      in
      Array.iter accounts ~f:(fun account ->
          Ledger.create_new_account_exn ledger
            (Account.identifier account)
            account ) ;
      let get_account aid =
        Option.bind
          (Ledger.location_of_account ledger aid)
          ~f:(Ledger.get ledger)
      in
      let nonce =
        match nonce with
        | Some nonce ->
            nonce
        | None -> (
            match get_account (Account_id.create fee_payer_pk fee_token) with
            | Some { nonce; _ } ->
                nonce
            | None ->
                failwith
                  "Could not infer a valid nonce for this test. Provide one \
                   explicitly" )
      in
      let payload =
        Signed_command.Payload.create ~fee ~fee_payer_pk ~nonce ~valid_until
          ~memo ~body
      in
      let signer = Signature_lib.Keypair.of_private_key_exn signer in
      let user_command = Signed_command.sign signer payload in
      U.test_transaction_union ledger (Command (Signed_command user_command)) ;
      let fee_payer = Signed_command.Payload.fee_payer payload in
      let source = Signed_command.Payload.source payload in
      let receiver = Signed_command.Payload.receiver payload in
      let fee_payer_account = get_account fee_payer in
      let source_account = get_account source in
      let receiver_account = get_account receiver in
      ( `Fee_payer_account fee_payer_account
      , `Source_account source_account
      , `Receiver_account receiver_account )

    let random_int_incl l u = Quickcheck.random_value (Int.gen_incl l u)

    let sub_amount amt bal = Option.value_exn (Balance.sub_amount bal amt)

    let sub_fee fee = sub_amount (Amount.of_fee fee)

    (*TODO: test with zkapp_command transactions
        let%test_unit "transfer non-default tokens to a new account: fails but \
                       charges fee" =
          Test_util.with_randomness 123456789 (fun () ->
              Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                  let wallets = U.Wallet.random_wallets ~n:2 () in
                  let signer = wallets.(0).private_key in
                  let fee_payer_pk = wallets.(0).account.public_key in
                  let source_pk = fee_payer_pk in
                  let receiver_pk = wallets.(1).account.public_key in
                  let fee_token = Token_id.default in
                  let token_id = Quickcheck.random_value Token_id.gen_non_default in
                  let accounts =
                    [| create_account fee_payer_pk fee_token 20_000_000_000
                     ; create_account source_pk token_id 30_000_000_000
                    |]
                  in
                  let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                  let amount =
                    Amount.of_int (random_int_incl 0 30 * 1_000_000_000)
                  in
                  let ( `Fee_payer_account fee_payer_account
                      , `Source_account source_account
                      , `Receiver_account receiver_account ) =
                    test_user_command_with_accounts ~ledger
                      ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                      (Payment { source_pk; receiver_pk; amount })
                  in
                  let fee_payer_account = Option.value_exn fee_payer_account in
                  let source_account = Option.value_exn source_account in
                  let expected_fee_payer_balance =
                    accounts.(0).balance |> sub_fee fee
                  in
                  assert (
                    Balance.equal fee_payer_account.balance
                      expected_fee_payer_balance ) ;
                  assert (Balance.equal accounts.(1).balance source_account.balance) ;
                  assert (Option.is_none receiver_account)))

        let%test_unit "transfer non-default tokens to an existing account" =
          Test_util.with_randomness 123456789 (fun () ->
              Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                  let wallets = U.Wallet.random_wallets ~n:2 () in
                  let signer = wallets.(0).private_key in
                  let fee_payer_pk = wallets.(0).account.public_key in
                  let source_pk = fee_payer_pk in
                  let receiver_pk = wallets.(1).account.public_key in
                  let fee_token = Token_id.default in
                  let token_id = Quickcheck.random_value Token_id.gen_non_default in
                  let accounts =
                    [| create_account fee_payer_pk fee_token 20_000_000_000
                     ; create_account source_pk token_id 30_000_000_000
                     ; create_account receiver_pk token_id 0
                    |]
                  in
                  let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                  let amount =
                    Amount.of_int (random_int_incl 0 30 * 1_000_000_000)
                  in
                  let ( `Fee_payer_account fee_payer_account
                      , `Source_account source_account
                      , `Receiver_account receiver_account ) =
                    test_user_command_with_accounts ~ledger
                      ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                      (Payment { source_pk; receiver_pk; amount })
                  in
                  let fee_payer_account = Option.value_exn fee_payer_account in
                  let source_account = Option.value_exn source_account in
                  let receiver_account = Option.value_exn receiver_account in
                  let expected_fee_payer_balance =
                    accounts.(0).balance |> sub_fee fee
                  in
                  assert (
                    Balance.equal fee_payer_account.balance
                      expected_fee_payer_balance ) ;
                  let expected_source_balance =
                    accounts.(1).balance |> sub_amount amount
                  in
                  assert (
                    Balance.equal source_account.balance expected_source_balance ) ;
                  let expected_receiver_balance =
                    accounts.(2).balance |> add_amount amount
                  in
                  assert (
                    Balance.equal receiver_account.balance expected_receiver_balance
                  )))

        let%test_unit "insufficient account creation fee for non-default token \
                       transfer" =
          Test_util.with_randomness 123456789 (fun () ->
              Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                  let wallets = U.Wallet.random_wallets ~n:2 () in
                  let signer = wallets.(0).private_key in
                  let fee_payer_pk = wallets.(0).account.public_key in
                  let source_pk = fee_payer_pk in
                  let receiver_pk = wallets.(1).account.public_key in
                  let fee_token = Token_id.default in
                  let token_id = Quickcheck.random_value Token_id.gen_non_default in
                  let accounts =
                    [| create_account fee_payer_pk fee_token 20_000_000_000
                     ; create_account source_pk token_id 30_000_000_000
                    |]
                  in
                  let fee = Fee.of_int 20_000_000_000 in
                  let amount =
                    Amount.of_int (random_int_incl 0 30 * 1_000_000_000)
                  in
                  let ( `Fee_payer_account fee_payer_account
                      , `Source_account source_account
                      , `Receiver_account receiver_account ) =
                    test_user_command_with_accounts ~constraint_constants ~ledger
                      ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                      (Payment { source_pk; receiver_pk; amount })
                  in
                  let fee_payer_account = Option.value_exn fee_payer_account in
                  let source_account = Option.value_exn source_account in
                  let expected_fee_payer_balance =
                    accounts.(0).balance |> sub_fee fee
                  in
                  assert (
                    Balance.equal fee_payer_account.balance
                      expected_fee_payer_balance ) ;
                  let expected_source_balance = accounts.(1).balance in
                  assert (
                    Balance.equal source_account.balance expected_source_balance ) ;
                  assert (Option.is_none receiver_account)))

        let%test_unit "insufficient source balance for non-default token transfer" =
          Test_util.with_randomness 123456789 (fun () ->
              Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                  let wallets = U.Wallet.random_wallets ~n:2 () in
                  let signer = wallets.(0).private_key in
                  let fee_payer_pk = wallets.(0).account.public_key in
                  let source_pk = fee_payer_pk in
                  let receiver_pk = wallets.(1).account.public_key in
                  let fee_token = Token_id.default in
                  let token_id = Quickcheck.random_value Token_id.gen_non_default in
                  let accounts =
                    [| create_account fee_payer_pk fee_token 20_000_000_000
                     ; create_account source_pk token_id 30_000_000_000
                    |]
                  in
                  let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                  let amount = Amount.of_int 40_000_000_000 in
                  let ( `Fee_payer_account fee_payer_account
                      , `Source_account source_account
                      , `Receiver_account receiver_account ) =
                    test_user_command_with_accounts ~constraint_constants ~ledger
                      ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                      (Payment { source_pk; receiver_pk; amount })
                  in
                  let fee_payer_account = Option.value_exn fee_payer_account in
                  let source_account = Option.value_exn source_account in
                  let expected_fee_payer_balance =
                    accounts.(0).balance |> sub_fee fee
                  in
                  assert (
                    Balance.equal fee_payer_account.balance
                      expected_fee_payer_balance ) ;
                  let expected_source_balance = accounts.(1).balance in
                  assert (
                    Balance.equal source_account.balance expected_source_balance ) ;
                  assert (Option.is_none receiver_account)))


      let%test_unit "transfer non-existing source" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                let fee_payer_pk = wallets.(0).account.public_key in
                let source_pk = wallets.(1).account.public_key in
                let receiver_pk = wallets.(2).account.public_key in
                let fee_token = Token_id.default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000 |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let amount = Amount.of_int 5_000_000_000 in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account source_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Payment { source_pk; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Option.is_none source_account) ;
                assert (Option.is_none receiver_account)))*)

    let%test_unit "delegation delegatee does not exist" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = U.Wallet.random_wallets ~n:2 () in
              let signer = wallets.(0).private_key in
              let fee_payer_pk = wallets.(0).account.public_key in
              let source_pk = fee_payer_pk in
              let receiver_pk = wallets.(1).account.public_key in
              let fee_token = Token_id.default in
              let accounts =
                [| create_account fee_payer_pk fee_token 20_000_000_000 |]
              in
              let fee = Fee.of_mina_int_exn @@ random_int_incl 2 15 in
              let ( `Fee_payer_account fee_payer_account
                  , `Source_account source_account
                  , `Receiver_account receiver_account ) =
                test_user_command_with_accounts ~ledger ~accounts ~signer ~fee
                  ~fee_payer_pk ~fee_token
                  (Stake_delegation
                     (Set_delegate
                        { delegator = source_pk; new_delegate = receiver_pk } )
                  )
              in
              let fee_payer_account = Option.value_exn fee_payer_account in
              let source_account = Option.value_exn source_account in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              assert (
                Public_key.Compressed.equal
                  (Option.value_exn source_account.delegate)
                  source_pk ) ;
              assert (Option.is_none receiver_account) ) )

    let%test_unit "delegation delegator does not exist" =
      Test_util.with_randomness 123456789 (fun () ->
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let wallets = U.Wallet.random_wallets ~n:3 () in
              let signer = wallets.(0).private_key in
              let fee_payer_pk = wallets.(0).account.public_key in
              let source_pk = wallets.(1).account.public_key in
              let receiver_pk = wallets.(2).account.public_key in
              let fee_token = Token_id.default in
              let token_id = Token_id.default in
              let accounts =
                [| create_account fee_payer_pk fee_token 20_000_000_000
                 ; create_account receiver_pk token_id 30_000_000_000
                |]
              in
              let fee = Fee.of_mina_int_exn @@ random_int_incl 2 15 in
              let ( `Fee_payer_account fee_payer_account
                  , `Source_account source_account
                  , `Receiver_account receiver_account ) =
                test_user_command_with_accounts ~ledger ~accounts ~signer ~fee
                  ~fee_payer_pk ~fee_token
                  (Stake_delegation
                     (Set_delegate
                        { delegator = source_pk; new_delegate = receiver_pk } )
                  )
              in
              let fee_payer_account = Option.value_exn fee_payer_account in
              let expected_fee_payer_balance =
                accounts.(0).balance |> sub_fee fee
              in
              assert (
                Balance.equal fee_payer_account.balance
                  expected_fee_payer_balance ) ;
              assert (Option.is_none source_account) ;
              assert (Option.is_some receiver_account) ) )

    let%test_unit "timed account - transactions" =
      Test_util.with_randomness 123456789 (fun () ->
          let wallets = U.Wallet.random_wallets ~n:3 () in
          let sender = wallets.(0) in
          let receivers = Array.to_list wallets |> List.tl_exn in
          let txns_per_receiver = 2 in
          let amount = 8_000_000_000 in
          let txn_fee = 2_000_000_000 in
          let memo =
            Signed_command_memo.create_by_digesting_string_exn
              (Test_util.arbitrary_string
                 ~len:Signed_command_memo.max_digestible_string_length )
          in
          let balance = Balance.of_mina_int_exn 100_000 in
          let initial_minimum_balance = Balance.of_mina_int_exn 80_000 in
          let cliff_time = Mina_numbers.Global_slot.of_int 1000 in
          let cliff_amount = Amount.of_nanomina_int_exn 10_000 in
          let vesting_period = Mina_numbers.Global_slot.of_int 10 in
          let vesting_increment = Amount.of_nanomina_int_exn 1 in
          let txn_global_slot = Mina_numbers.Global_slot.of_int 1002 in
          let sender =
            { sender with
              account =
                Or_error.ok_exn
                @@ Account.create_timed
                     (Account.identifier sender.account)
                     balance ~initial_minimum_balance ~cliff_time ~cliff_amount
                     ~vesting_period ~vesting_increment
            }
          in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              let _, ucs =
                let receiver_ids =
                  List.init (List.length receivers) ~f:(( + ) 1)
                in
                let receivers =
                  List.fold ~init:receiver_ids
                    (List.init (txns_per_receiver - 1) ~f:Fn.id)
                    ~f:(fun acc _ -> receiver_ids @ acc)
                in
                List.fold receivers ~init:(Account.Nonce.zero, [])
                  ~f:(fun (nonce, txns) receiver ->
                    let uc =
                      U.Wallet.user_command_with_wallet wallets ~sender:0
                        ~receiver amount
                        (Fee.of_nanomina_int_exn txn_fee)
                        nonce memo
                    in
                    (Account.Nonce.succ nonce, txns @ [ uc ]) )
              in
              Ledger.create_new_account_exn ledger
                (Account.identifier sender.account)
                sender.account ;
              let () =
                List.iter ucs ~f:(fun uc ->
                    U.test_transaction_union ~txn_global_slot ledger
                      (Transaction.Command (Signed_command uc)) )
              in
              List.iter receivers ~f:(fun receiver ->
                  U.check_balance
                    (Account.identifier receiver.account)
                    ((amount * txns_per_receiver) - account_fee)
                    ledger ) ;
              U.check_balance
                (Account.identifier sender.account)
                ( Balance.to_nanomina_int sender.account.balance
                - (amount + txn_fee) * txns_per_receiver * List.length receivers
                )
                ledger ) )

    (*TODO: use zkApp transactions for tokens*)
    (*let%test_unit "create own new token" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:1 () in
                let signer = wallets.(0).private_key in
                (* Fee payer is the new token owner. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let fee_token = Token_id.default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000 |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account _also_token_owner_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_new_token
                       { token_owner_pk; disable_new_accounts = false })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Option.is_none token_owner_account.delegate) ;
                assert (
                  Token_permissions.equal token_owner_account.token_permissions
                    (Token_owned { disable_new_accounts = false }) )))

      let%test_unit "create new token for a different pk" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee payer and new token owner are distinct. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000 |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account _also_token_owner_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_new_token
                       { token_owner_pk; disable_new_accounts = false })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Option.is_none token_owner_account.delegate) ;
                assert (
                  Token_permissions.equal token_owner_account.token_permissions
                    (Token_owned { disable_new_accounts = false }) )))

      let%test_unit "create new token for a different pk new accounts disabled" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee payer and new token owner are distinct. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000 |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account _also_token_owner_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_new_token
                       { token_owner_pk; disable_new_accounts = true })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Option.is_none token_owner_account.delegate) ;
                assert (
                  Token_permissions.equal token_owner_account.token_permissions
                    (Token_owned { disable_new_accounts = true }) )))

      let%test_unit "create own new token account" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and receiver are the same, token owner differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = fee_payer_pk in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Balance.(equal zero) receiver_account.balance) ;
                assert (Option.is_none receiver_account.delegate) ;
                assert (
                  Token_permissions.equal receiver_account.token_permissions
                    (Not_owned { account_disabled = false }) )))

      let%test_unit "create new token account for a different pk" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:3 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner differ. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = wallets.(2).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Balance.(equal zero) receiver_account.balance) ;
                assert (Option.is_none receiver_account.delegate) ;
                assert (
                  Token_permissions.equal receiver_account.token_permissions
                    (Not_owned { account_disabled = false }) )))

      let%test_unit "create new token account for a different pk in a locked \
                     token" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and token owner are the same, receiver differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = true }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Balance.(equal zero) receiver_account.balance) ;
                assert (Option.is_none receiver_account.delegate) ;
                assert (
                  Token_permissions.equal receiver_account.token_permissions
                    (Not_owned { account_disabled = false }) )))

      let%test_unit "create new own locked token account in a locked token" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and receiver are the same, token owner differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = fee_payer_pk in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = true }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = true
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Balance.(equal zero) receiver_account.balance) ;
                assert (Option.is_none receiver_account.delegate) ;
                assert (
                  Token_permissions.equal receiver_account.token_permissions
                    (Not_owned { account_disabled = true }) )))

      let%test_unit "create new token account fails for locked token, non-owner \
                     fee-payer" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:3 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner differ. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = wallets.(2).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = true }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Option.is_none receiver_account)))

      let%test_unit "create new locked token account fails for unlocked token, \
                     non-owner fee-payer" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:3 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner differ. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = wallets.(2).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = true
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Option.is_none receiver_account)))

      let%test_unit "create new token account fails if account exists" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:3 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner differ. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = wallets.(2).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                   ; create_account receiver_pk token_id 0
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let receiver_account = Option.value_exn receiver_account in
                (* No account creation fee: the command fails. *)
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Balance.(equal zero) receiver_account.balance)))

      let%test_unit "create new token account fails if receiver is token owner" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Receiver and token owner are the same, fee-payer differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = token_owner_pk in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let receiver_account = Option.value_exn receiver_account in
                (* No account creation fee: the command fails. *)
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Balance.(equal zero) receiver_account.balance)))

      let%test_unit "create new token account fails if claimed token owner \
                     doesn't own the token" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:3 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner differ. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = wallets.(2).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; create_account token_owner_pk token_id 0
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                (* No account creation fee: the command fails. *)
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) token_owner_account.balance) ;
                assert (Option.is_none receiver_account)))

      let%test_unit "create new token account fails if claimed token owner is \
                     also the account creation target and does not exist" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:3 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner are the same. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000 |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk = fee_payer_pk
                       ; token_id
                       ; receiver_pk = fee_payer_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                (* No account creation fee: the command fails. *)
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Option.is_none token_owner_account) ;
                assert (Option.is_none receiver_account)))

      let%test_unit "create new token account works for default token" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and receiver are the same, token owner differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Token_id.default in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000 |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account _token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Create_token_account
                       { token_owner_pk
                       ; token_id
                       ; receiver_pk
                       ; account_disabled = false
                       })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                  |> sub_fee constraint_constants.account_creation_fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Balance.(equal zero) receiver_account.balance) ;
                assert (
                  Public_key.Compressed.equal receiver_pk
                    (Option.value_exn receiver_account.delegate) ) ;
                assert (
                  Token_permissions.equal receiver_account.token_permissions
                    (Not_owned { account_disabled = false }) )))

      let%test_unit "mint tokens in owner's account" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:1 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer, receiver, and token owner are the same. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = fee_payer_pk in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let amount =
                  Amount.of_int (random_int_incl 2 15 * 1_000_000_000)
                in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account _token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Mint_tokens { token_owner_pk; token_id; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                let expected_receiver_balance =
                  accounts.(1).balance |> add_amount amount
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (
                  Balance.equal expected_receiver_balance receiver_account.balance
                )))

      let%test_unit "mint tokens in another pk's account" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and token owner are the same, receiver differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let amount =
                  Amount.of_int (random_int_incl 2 15 * 1_000_000_000)
                in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                   ; create_account receiver_pk token_id 0
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Mint_tokens { token_owner_pk; token_id; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let receiver_account = Option.value_exn receiver_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                let expected_receiver_balance =
                  accounts.(2).balance |> add_amount amount
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (
                  Balance.equal accounts.(1).balance token_owner_account.balance
                ) ;
                assert (
                  Balance.equal expected_receiver_balance receiver_account.balance
                )))

      let%test_unit "mint tokens fails if the claimed token owner is not the \
                     token owner" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and token owner are the same, receiver differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let amount =
                  Amount.of_int (random_int_incl 2 15 * 1_000_000_000)
                in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; create_account token_owner_pk token_id 0
                   ; create_account receiver_pk token_id 0
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Mint_tokens { token_owner_pk; token_id; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let receiver_account = Option.value_exn receiver_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (
                  Balance.equal accounts.(1).balance token_owner_account.balance
                ) ;
                assert (
                  Balance.equal accounts.(2).balance receiver_account.balance )))

      let%test_unit "mint tokens fails if the token owner account is not present"
          =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and token owner are the same, receiver differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let amount =
                  Amount.of_int (random_int_incl 2 15 * 1_000_000_000)
                in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; create_account receiver_pk token_id 0
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Mint_tokens { token_owner_pk; token_id; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let receiver_account = Option.value_exn receiver_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (Option.is_none token_owner_account) ;
                assert (
                  Balance.equal accounts.(1).balance receiver_account.balance )))

      let%test_unit "mint tokens fails if the fee-payer does not have permission \
                     to mint" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and receiver are the same, token owner differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = wallets.(1).account.public_key in
                let receiver_pk = fee_payer_pk in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let amount =
                  Amount.of_int (random_int_incl 2 15 * 1_000_000_000)
                in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                   ; create_account receiver_pk token_id 0
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Mint_tokens { token_owner_pk; token_id; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let receiver_account = Option.value_exn receiver_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (
                  Balance.equal accounts.(1).balance token_owner_account.balance
                ) ;
                assert (
                  Balance.equal accounts.(2).balance receiver_account.balance )))

      let%test_unit "mint tokens fails if the receiver account is not present" =
        Test_util.with_randomness 123456789 (fun () ->
            Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
                let wallets = U.Wallet.random_wallets ~n:2 () in
                let signer = wallets.(0).private_key in
                (* Fee-payer and fee payer are the same, receiver differs. *)
                let fee_payer_pk = wallets.(0).account.public_key in
                let token_owner_pk = fee_payer_pk in
                let receiver_pk = wallets.(1).account.public_key in
                let fee_token = Token_id.default in
                let token_id = Quickcheck.random_value Token_id.gen_non_default in
                let amount =
                  Amount.of_int (random_int_incl 2 15 * 1_000_000_000)
                in
                let accounts =
                  [| create_account fee_payer_pk fee_token 20_000_000_000
                   ; { (create_account token_owner_pk token_id 0) with
                       token_permissions =
                         Token_owned { disable_new_accounts = false }
                     }
                  |]
                in
                let fee = Fee.of_int (random_int_incl 2 15 * 1_000_000_000) in
                let ( `Fee_payer_account fee_payer_account
                    , `Source_account token_owner_account
                    , `Receiver_account receiver_account ) =
                  test_user_command_with_accounts ~constraint_constants ~ledger
                    ~accounts ~signer ~fee ~fee_payer_pk ~fee_token
                    (Mint_tokens { token_owner_pk; token_id; receiver_pk; amount })
                in
                let fee_payer_account = Option.value_exn fee_payer_account in
                let token_owner_account = Option.value_exn token_owner_account in
                let expected_fee_payer_balance =
                  accounts.(0).balance |> sub_fee fee
                in
                assert (
                  Balance.equal fee_payer_account.balance
                    expected_fee_payer_balance ) ;
                assert (
                  Balance.equal accounts.(1).balance token_owner_account.balance
                ) ;
                assert (Option.is_none receiver_account)))*)

    let%test_unit "unchanged timings for fee transfers and coinbase" =
      Test_util.with_randomness 123456789 (fun () ->
          let receivers =
            Array.init 2 ~f:(fun _ ->
                Public_key.of_private_key_exn (Private_key.create ())
                |> Public_key.compress )
          in
          let timed_account pk =
            let account_id = Account_id.create pk Token_id.default in
            let balance = Balance.of_mina_int_exn 100_000 in
            let initial_minimum_balance = Balance.of_mina_int_exn 80 in
            let cliff_time = Mina_numbers.Global_slot.of_int 2 in
            let cliff_amount = Amount.of_mina_int_exn 5 in
            let vesting_period = Mina_numbers.Global_slot.of_int 2 in
            let vesting_increment = Amount.of_mina_int_exn 40 in
            Or_error.ok_exn
            @@ Account.create_timed account_id balance ~initial_minimum_balance
                 ~cliff_time ~cliff_amount ~vesting_period ~vesting_increment
          in
          let timed_account1 = timed_account receivers.(0) in
          let timed_account2 = timed_account receivers.(1) in
          let fee = 8_000_000_000 in
          let ft1, ft2 =
            let single1 =
              Fee_transfer.Single.create ~receiver_pk:receivers.(0)
                ~fee:(Currency.Fee.of_nanomina_int_exn fee)
                ~fee_token:Token_id.default
            in
            let single2 =
              Fee_transfer.Single.create ~receiver_pk:receivers.(1)
                ~fee:(Currency.Fee.of_nanomina_int_exn fee)
                ~fee_token:Token_id.default
            in
            ( Fee_transfer.create single1 (Some single2) |> Or_error.ok_exn
            , Fee_transfer.create single1 None |> Or_error.ok_exn )
          in
          let coinbase_with_ft, coinbase_wo_ft =
            let ft =
              Coinbase.Fee_transfer.create ~receiver_pk:receivers.(0)
                ~fee:(Currency.Fee.of_nanomina_int_exn fee)
            in
            ( Coinbase.create
                ~amount:(Currency.Amount.of_mina_int_exn 10)
                ~receiver:receivers.(1) ~fee_transfer:(Some ft)
              |> Or_error.ok_exn
            , Coinbase.create
                ~amount:(Currency.Amount.of_mina_int_exn 10)
                ~receiver:receivers.(1) ~fee_transfer:None
              |> Or_error.ok_exn )
          in
          let transactions : Mina_transaction.Transaction.Valid.t list =
            [ Fee_transfer ft1
            ; Fee_transfer ft2
            ; Coinbase coinbase_with_ft
            ; Coinbase coinbase_wo_ft
            ]
          in
          Ledger.with_ledger ~depth:ledger_depth ~f:(fun ledger ->
              List.iter [ timed_account1; timed_account2 ] ~f:(fun acc ->
                  Ledger.create_new_account_exn ledger (Account.identifier acc)
                    acc ) ;
              (* well over the vesting period, the timing field shouldn't change*)
              let txn_global_slot = Mina_numbers.Global_slot.of_int 100 in
              List.iter transactions ~f:(fun txn ->
                  U.test_transaction_union ~txn_global_slot ledger txn ) ) )
  end )

let%test_module "legacy transactions using zkApp accounts" =
  ( module struct
    let memo = Signed_command_memo.create_from_string_exn "zkApp-legacy-txns"

    let `VK vk, `Prover _zkapp_prover = Lazy.force U.trivial_zkapp

    let account ledger pk =
      let location =
        Option.value_exn
          (Ledger.location_of_account ledger
             (Account_id.create pk Token_id.default) )
      in
      Option.value_exn (Ledger.get ledger location)

    let test_payments ?expected_failure_sender ?expected_failure_receiver
        ~(new_kp : Signature_lib.Keypair.t)
        ~(spec : Mina_transaction_logic.For_tests.Transaction_spec.t)
        ?permissions ledger =
      let expected_failure_receiver =
        Option.map expected_failure_receiver ~f:(fun f -> [ f ])
      in
      let expected_failure_sender =
        Option.map expected_failure_sender ~f:(fun f -> [ f ])
      in
      let zkapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
      Transaction_snark.For_tests.create_trivial_zkapp_account ?permissions ~vk
        ~ledger zkapp_pk ;
      let txn_fee = Fee.of_nanomina_int_exn 1_000_000 in
      let amount = 100 in
      (*send from a zkApp account*)
      let signed_command1 =
        let fee_payer =
          { U.Wallet.private_key = new_kp.private_key
          ; account = account ledger zkapp_pk
          }
        in
        U.Wallet.user_command ~fee_payer ~receiver_pk:spec.receiver amount
          txn_fee Account.Nonce.zero memo
      in
      U.test_transaction_union ?expected_failure:expected_failure_sender ledger
        (Mina_transaction.Transaction.Command (Signed_command signed_command1)) ;
      let sender_kp, sender_nonce = spec.sender in
      (*send to a zkApp account*)
      let signed_command2 =
        let source_pk =
          Signature_lib.Public_key.compress sender_kp.public_key
        in
        let fee_payer =
          { U.Wallet.private_key = sender_kp.private_key
          ; account = account ledger source_pk
          }
        in
        U.Wallet.user_command ~fee_payer ~receiver_pk:zkapp_pk amount txn_fee
          sender_nonce memo
      in
      U.test_transaction_union ?expected_failure:expected_failure_receiver
        ledger
        (Mina_transaction.Transaction.Command (Signed_command signed_command2))

    let%test_unit "Successful payments from zkapp accounts- Signature, None" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        send = Permissions.Auth_required.Signature
                      ; receive = Permissions.Auth_required.None
                      }
                  in
                  test_payments ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Successful payments from zkapp accounts- None,None" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        send = Permissions.Auth_required.None
                      ; receive = Permissions.Auth_required.None
                      }
                  in
                  test_payments ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed payments from zkapp accounts- Proof,None" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        send = Permissions.Auth_required.Proof
                      ; receive = Permissions.Auth_required.None
                      }
                  in
                  test_payments ?permissions
                    ~expected_failure_sender:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed payments from zkapp accounts- Signature,Signature" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        send = Permissions.Auth_required.Signature
                      ; receive = Permissions.Auth_required.Signature
                      }
                  in
                  test_payments ?permissions
                    ~expected_failure_receiver:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed payments from zkapp accounts- Signature,Proof" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        send = Permissions.Auth_required.Signature
                      ; receive = Permissions.Auth_required.Proof
                      }
                  in
                  test_payments ?permissions
                    ~expected_failure_receiver:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let test_delegations ?expected_failure_sender
        ~(new_kp : Signature_lib.Keypair.t)
        ~(spec : Mina_transaction_logic.For_tests.Transaction_spec.t)
        ?permissions ledger =
      let expected_failure =
        Option.map expected_failure_sender ~f:(fun f -> [ f ])
      in
      let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
      Transaction_snark.For_tests.create_trivial_zkapp_account ?permissions ~vk
        ~ledger snapp_pk ;
      let txn_fee = Fee.of_nanomina_int_exn 1_000_000 in
      let sender_kp, sender_nonce = spec.sender in
      (*Delegator is a zkapp account*)
      let stake_delegation1 =
        let fee_payer =
          { U.Wallet.private_key = new_kp.private_key
          ; account = account ledger snapp_pk
          }
        in
        U.Wallet.stake_delegation ~fee_payer ~delegate_pk:spec.receiver txn_fee
          Account.Nonce.zero memo
      in
      U.test_transaction_union ?expected_failure ledger
        (Mina_transaction.Transaction.Command (Signed_command stake_delegation1)) ;
      (*Delegate is a zkApp account*)
      let stake_delegation2 =
        let source_pk =
          Signature_lib.Public_key.compress sender_kp.public_key
        in
        let fee_payer =
          { U.Wallet.private_key = sender_kp.private_key
          ; account = account ledger source_pk
          }
        in
        U.Wallet.stake_delegation ~fee_payer ~delegate_pk:snapp_pk txn_fee
          sender_nonce memo
      in
      U.test_transaction_union ledger
        (Mina_transaction.Transaction.Command (Signed_command stake_delegation2))

    let%test_unit "Successful stake delegations from zkapp accounts- Signature"
        =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        set_delegate = Permissions.Auth_required.Signature
                      }
                  in
                  test_delegations ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Successful stake delegations from zkapp accounts- None" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        set_delegate = Permissions.Auth_required.None
                      }
                  in
                  test_delegations ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed stake delegation from zkapp accounts- Proof" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        set_delegate = Permissions.Auth_required.Proof
                      }
                  in
                  test_delegations ?permissions
                    ~expected_failure_sender:
                      Transaction_status.Failure.Update_not_permitted_delegate
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Successful stake delegation from zkapp accounts- \
                   receive=Proof" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.Proof
                      }
                  in
                  test_delegations ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let test_coinbase ?expected_failure_fee_receiver
        ~(new_kp : Signature_lib.Keypair.t)
        ~(spec : Mina_transaction_logic.For_tests.Transaction_spec.t)
        ?permissions ledger =
      let expected_failure =
        Option.map expected_failure_fee_receiver ~f:(fun f -> [ f ])
      in
      let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
      Transaction_snark.For_tests.create_trivial_zkapp_account ?permissions ~vk
        ~ledger snapp_pk ;
      let fee = Fee.of_nanomina_int_exn 1_000_000 in
      let amount = U.constraint_constants.coinbase_amount in
      (*send coinbase reward to a zkApp account*)
      let coinbase1 =
        let ft = Coinbase.Fee_transfer.create ~receiver_pk:spec.receiver ~fee in
        Coinbase.create ~amount ~receiver:snapp_pk ~fee_transfer:(Some ft)
        |> Or_error.ok_exn
      in
      U.test_transaction_union ?expected_failure ledger
        (Mina_transaction.Transaction.Coinbase coinbase1) ;
      (*coinbase fee transfer to a zkApp account*)
      let coinbase2 =
        let ft = Coinbase.Fee_transfer.create ~receiver_pk:snapp_pk ~fee in
        Coinbase.create ~amount ~receiver:spec.receiver ~fee_transfer:(Some ft)
        |> Or_error.ok_exn
      in
      U.test_transaction_union ?expected_failure ledger
        (Mina_transaction.Transaction.Coinbase coinbase2) ;
      (*coinbase reward and fee transfer to zkApp accounts*)
      let snapp_pk2 =
        Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
      in
      Transaction_snark.For_tests.create_trivial_zkapp_account ?permissions ~vk
        ~ledger snapp_pk2 ;
      let coinbase3 =
        let ft = Coinbase.Fee_transfer.create ~receiver_pk:snapp_pk ~fee in
        Coinbase.create ~amount ~receiver:snapp_pk2 ~fee_transfer:(Some ft)
        |> Or_error.ok_exn
      in
      U.test_transaction_union
        ?expected_failure:
          (Option.map expected_failure_fee_receiver ~f:(fun f -> [ f; f ]))
        ledger (Mina_transaction.Transaction.Coinbase coinbase3)

    let%test_unit "Successful coinbase to zkapp accounts" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.None
                      }
                  in
                  test_coinbase ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed coinbase to zkapp accounts- with proof auth" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.Proof
                      }
                  in
                  test_coinbase ?permissions
                    ~expected_failure_fee_receiver:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed coinbase to zkapp accounts- with signature Auth" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.Signature
                      }
                  in
                  test_coinbase ?permissions
                    ~expected_failure_fee_receiver:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let test_fee_transfers ?expected_failure_fee_receiver
        ~(new_kp : Signature_lib.Keypair.t)
        ~(spec : Mina_transaction_logic.For_tests.Transaction_spec.t)
        ?permissions ledger =
      let expected_failure =
        Option.map expected_failure_fee_receiver ~f:(fun f -> [ f ])
      in
      let snapp_pk = Signature_lib.Public_key.compress new_kp.public_key in
      Transaction_snark.For_tests.create_trivial_zkapp_account ?permissions ~vk
        ~ledger snapp_pk ;
      let fee = U.constraint_constants.account_creation_fee in
      (*send first one to a zkApp account*)
      let ft1, ft2 =
        let single1 =
          Fee_transfer.Single.create ~receiver_pk:snapp_pk ~fee
            ~fee_token:Token_id.default
        in
        let single2 =
          Fee_transfer.Single.create ~receiver_pk:spec.receiver ~fee
            ~fee_token:Token_id.default
        in
        ( Fee_transfer.create single1 (Some single2) |> Or_error.ok_exn
        , Fee_transfer.create single1 None |> Or_error.ok_exn )
      in
      List.iter [ ft1; ft2 ] ~f:(fun ft ->
          U.test_transaction_union ?expected_failure ledger
            (Mina_transaction.Transaction.Fee_transfer ft) ) ;
      (*send the second one to a zkApp account*)
      let ft3, ft4 =
        let single1 =
          Fee_transfer.Single.create ~receiver_pk:spec.receiver ~fee
            ~fee_token:Token_id.default
        in
        let single2 =
          Fee_transfer.Single.create ~receiver_pk:snapp_pk ~fee
            ~fee_token:Token_id.default
        in
        ( Fee_transfer.create single1 (Some single2) |> Or_error.ok_exn
        , Fee_transfer.create single1 None |> Or_error.ok_exn )
      in
      U.test_transaction_union ?expected_failure ledger
        (Mina_transaction.Transaction.Fee_transfer ft3) ;
      U.test_transaction_union ledger
        (Mina_transaction.Transaction.Fee_transfer ft4) ;
      (*send the both to zkApp accounts*)
      let snapp_pk2 =
        Quickcheck.random_value Signature_lib.Public_key.Compressed.gen
      in
      Transaction_snark.For_tests.create_trivial_zkapp_account ?permissions ~vk
        ~ledger snapp_pk2 ;
      let ft5 =
        let single1 =
          Fee_transfer.Single.create ~receiver_pk:snapp_pk ~fee
            ~fee_token:Token_id.default
        in
        let single2 =
          Fee_transfer.Single.create ~receiver_pk:snapp_pk2 ~fee
            ~fee_token:Token_id.default
        in
        Fee_transfer.create single1 (Some single2) |> Or_error.ok_exn
      in
      U.test_transaction_union
        ?expected_failure:
          (Option.map expected_failure_fee_receiver ~f:(fun f -> [ f; f ]))
        ledger (Mina_transaction.Transaction.Fee_transfer ft5)

    let%test_unit "Successful fee transfers to zkapp accounts" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.None
                      }
                  in
                  test_fee_transfers ?permissions ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed fee transfers to zkapp accounts- with proof auth" =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.Proof
                      }
                  in
                  test_fee_transfers ?permissions
                    ~expected_failure_fee_receiver:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )

    let%test_unit "Failed fee transfers to zkapp accounts- with signature Auth"
        =
      let open Mina_transaction_logic.For_tests in
      Quickcheck.test ~trials:5 U.gen_snapp_ledger
        ~f:(fun ({ init_ledger; specs }, new_kp) ->
          Ledger.with_ledger ~depth:U.ledger_depth ~f:(fun ledger ->
              Async.Thread_safe.block_on_async_exn (fun () ->
                  Init_ledger.init
                    (module Ledger.Ledger_inner)
                    init_ledger ledger ;
                  let spec = List.hd_exn specs in
                  let permissions =
                    Some
                      { Permissions.user_default with
                        receive = Permissions.Auth_required.Signature
                      }
                  in
                  test_fee_transfers ?permissions
                    ~expected_failure_fee_receiver:
                      Transaction_status.Failure.Update_not_permitted_balance
                    ~new_kp ~spec ledger ;
                  Async.Deferred.return () ) ) )
  end )
