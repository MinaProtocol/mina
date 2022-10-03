open Core
open Signature_lib
open Mina_base
open Mina_transaction

let name = "transaction-snark-profiler"

let constraint_constants = Genesis_constants.Constraint_constants.compiled

let genesis_constants = Genesis_constants.compiled

let proof_level = Genesis_constants.Proof_level.compiled

(* We're just profiling, so okay to monkey-patch here *)
module Sparse_ledger = struct
  include Mina_ledger.Sparse_ledger

  let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
end

let create_ledger_and_transactions num_transactions :
    Mina_ledger.Ledger.t * _ User_command.t_ Transaction.t_ list =
  let num_accounts = 4 in
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let ledger =
    Mina_ledger.Ledger.create ~depth:constraint_constants.ledger_depth ()
  in
  let keys =
    Array.init num_accounts ~f:(fun _ -> Signature_lib.Keypair.create ())
  in
  Array.iter keys ~f:(fun k ->
      let public_key = Public_key.compress k.public_key in
      let account_id = Account_id.create public_key Token_id.default in
      Mina_ledger.Ledger.create_new_account_exn ledger account_id
        (Account.create account_id
           (Currency.Balance.of_uint64
              (Unsigned.UInt64.of_int64 Int64.max_value) ) ) ) ;
  let txn (from_kp : Signature_lib.Keypair.t) (to_kp : Signature_lib.Keypair.t)
      amount fee nonce =
    let to_pk = Public_key.compress to_kp.public_key in
    let from_pk = Public_key.compress from_kp.public_key in
    let payload : Signed_command.Payload.t =
      Signed_command.Payload.create ~fee ~fee_payer_pk:from_pk ~nonce
        ~memo:Signed_command_memo.dummy ~valid_until:None
        ~body:(Payment { source_pk = from_pk; receiver_pk = to_pk; amount })
    in
    Signed_command.sign from_kp payload
  in
  let nonces =
    Public_key.Compressed.Table.of_alist_exn
      (List.map (Array.to_list keys) ~f:(fun k ->
           (Public_key.compress k.public_key, Account.Nonce.zero) ) )
  in
  let random_transaction () : Signed_command.With_valid_signature.t =
    let sender_idx = Random.int num_accounts in
    let sender = keys.(sender_idx) in
    let receiver = keys.(Random.int num_accounts) in
    let sender_pk = Public_key.compress sender.public_key in
    let nonce = Hashtbl.find_exn nonces sender_pk in
    Hashtbl.change nonces sender_pk ~f:(Option.map ~f:Account.Nonce.succ) ;
    let fee = Currency.Fee.nanomina_of_int_exn (1 + Random.int 100) in
    let amount = Currency.Amount.nanomina_of_int_exn (1 + Random.int 100) in
    txn sender receiver amount fee nonce
  in
  match num_transactions with
  | `Count n ->
      let num_transactions = n - 2 in
      let transactions =
        List.rev (List.init num_transactions ~f:(fun _ -> random_transaction ()))
      in
      let fee_transfer =
        let open Currency.Fee in
        let total_fee =
          List.fold transactions ~init:zero ~f:(fun acc t ->
              Option.value_exn
                (add acc
                   (Signed_command.Payload.fee (t :> Signed_command.t).payload) ) )
        in
        Fee_transfer.create_single
          ~receiver_pk:(Public_key.compress keys.(0).public_key)
          ~fee:total_fee ~fee_token:Token_id.default
      in
      let coinbase =
        Coinbase.create ~amount:constraint_constants.coinbase_amount
          ~receiver:(Public_key.compress keys.(0).public_key)
          ~fee_transfer:None
        |> Or_error.ok_exn
      in
      let transactions =
        List.map transactions ~f:(fun t ->
            Transaction.Command (User_command.Signed_command t) )
        @ [ Coinbase coinbase; Fee_transfer fee_transfer ]
      in
      (ledger, transactions)
  | `Two_from_same ->
      let a =
        txn keys.(0) keys.(1)
          (Currency.Amount.nanomina_of_int_exn 10)
          Currency.Fee.zero Account.Nonce.zero
      in
      let b =
        txn keys.(0) keys.(1)
          (Currency.Amount.nanomina_of_int_exn 10)
          Currency.Fee.zero
          (Account.Nonce.succ Account.Nonce.zero)
      in
      (ledger, [ Command (Signed_command a); Command (Signed_command b) ])

let create_ledger_and_zkapps num_transactions :
    Mina_ledger.Ledger.t * Zkapp_command.t list =
  let length =
    match num_transactions with
    | `Count length ->
        length
    | `Two_from_same ->
        failwith "Must provide a count when profiling with snapps"
  in
  let max_account_updates =
    let min_max =
      Mina_generators.Zkapp_command_generators.max_account_updates
    in
    Quickcheck.random_value (Int.gen_incl min_max 20)
  in
  let `VK vk, `Prover prover =
    Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ()
  in
  let cmd_infos, ledger =
    Quickcheck.random_value
      (Mina_generators.User_command_generators
       .sequence_zkapp_command_with_ledger ~max_account_updates ~length ~vk () )
  in
  let zkapps =
    List.map cmd_infos ~f:(fun (user_cmd, _keypair, keymap) ->
        match user_cmd with
        | User_command.Zkapp_command zkapp_command_valid ->
            Async.Thread_safe.block_on_async_exn (fun () ->
                Zkapp_command_builder.replace_authorizations ~prover ~keymap
                  (Zkapp_command.Valid.forget zkapp_command_valid) )
        | User_command.Signed_command _ ->
            failwith "Expected Zkapp_command user command" )
  in
  (ledger, zkapps)

let time thunk =
  let start = Time.now () in
  let x = thunk () in
  let stop = Time.now () in
  (Time.diff stop start, x)

let rec pair_up = function
  | [] ->
      []
  | x :: y :: xs ->
      (x, y) :: pair_up xs
  | _ ->
      failwith "Expected even length list"

let precomputed_values = Precomputed_values.compiled_inputs

let state_body =
  Mina_state.(
    Lazy.map precomputed_values ~f:(fun values ->
        values.protocol_state_with_hashes.data |> Protocol_state.body ))

let curr_state_view = Lazy.map state_body ~f:Mina_state.Protocol_state.Body.view

let state_body_hash = Lazy.map ~f:Mina_state.Protocol_state.Body.hash state_body

let pending_coinbase_stack_target (t : Transaction.t) stack =
  let stack_with_state =
    Pending_coinbase.Stack.(push_state (Lazy.force state_body_hash) stack)
  in
  let target =
    match t with
    | Coinbase c ->
        Pending_coinbase.(Stack.push_coinbase c stack_with_state)
    | _ ->
        stack_with_state
  in
  target

let format_time_span ts =
  sprintf !"Total time was: %{Time.Span.to_string_hum}" ts

(* This gives the "wall-clock time" to snarkify the given list of transactions, assuming
   unbounded parallelism. *)
let profile_user_command (module T : Transaction_snark.S) sparse_ledger0
    (transitions : Transaction.Valid.t list) _ : string Async.Deferred.t =
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let txn_state_view = Lazy.force curr_state_view in
  let open Async.Deferred.Let_syntax in
  let%bind (base_proof_time, _, _), base_proofs_rev =
    Async.Deferred.List.fold transitions
      ~init:((Time.Span.zero, sparse_ledger0, Pending_coinbase.Stack.empty), [])
      ~f:(fun ((max_span, sparse_ledger, coinbase_stack_source), proofs) t ->
        let sparse_ledger', _applied =
          Sparse_ledger.apply_transaction ~constraint_constants ~txn_state_view
            sparse_ledger (Transaction.forget t)
          |> Or_error.ok_exn
        in
        let coinbase_stack_target =
          pending_coinbase_stack_target (Transaction.forget t)
            coinbase_stack_source
        in
        let tm0 = Core.Unix.gettimeofday () in
        let%map proof =
          T.of_non_zkapp_command_transaction
            ~statement:
              { sok_digest = Sok_message.Digest.default
              ; source =
                  { ledger = Sparse_ledger.merkle_root sparse_ledger
                  ; pending_coinbase_stack = coinbase_stack_source
                  ; local_state = Mina_state.Local_state.empty ()
                  }
              ; target =
                  { ledger = Sparse_ledger.merkle_root sparse_ledger'
                  ; pending_coinbase_stack = coinbase_stack_target
                  ; local_state = Mina_state.Local_state.empty ()
                  }
              ; supply_increase =
                  (let magnitude =
                     Transaction.expected_supply_increase t |> Or_error.ok_exn
                   in
                   let sgn = Sgn.Pos in
                   Currency.Amount.Signed.create ~magnitude ~sgn )
              ; fee_excess =
                  Transaction.fee_excess (Transaction.forget t)
                  |> Or_error.ok_exn
              }
            ~init_stack:coinbase_stack_source
            { Transaction_protocol_state.Poly.transaction = t
            ; block_data = Lazy.force state_body
            }
            (unstage (Sparse_ledger.handler sparse_ledger))
        in
        let tm1 = Core.Unix.gettimeofday () in
        let span = Time.Span.of_sec (tm1 -. tm0) in
        ( (Time.Span.max span max_span, sparse_ledger', coinbase_stack_target)
        , proof :: proofs ) )
  in
  let rec merge_all serial_time proofs =
    match proofs with
    | [ _ ] ->
        Async.Deferred.return serial_time
    | _ ->
        let%bind layer_time, new_proofs_rev =
          Async.Deferred.List.fold (pair_up proofs) ~init:(Time.Span.zero, [])
            ~f:(fun (max_time, proofs) (x, y) ->
              let tm0 = Core.Unix.gettimeofday () in
              let%map proof =
                match%map
                  T.merge ~sok_digest:Sok_message.Digest.default x y
                with
                | Ok proof ->
                    proof
                | Error _ ->
                    failwith "merge failed"
              in
              let tm1 = Core.Unix.gettimeofday () in
              let pair_time = Time.Span.of_sec (tm1 -. tm0) in
              (Time.Span.max max_time pair_time, proof :: proofs) )
        in
        merge_all
          (Time.Span.( + ) serial_time layer_time)
          (List.rev new_proofs_rev)
  in
  let%map total_time = merge_all base_proof_time (List.rev base_proofs_rev) in
  format_time_span total_time

let profile_zkapps ~verifier ledger zkapp_commands =
  let open Async.Deferred.Let_syntax in
  let tm0 = Core.Unix.gettimeofday () in
  let%map () =
    let num_zkapp_commands = List.length zkapp_commands in
    Async.Deferred.List.iteri zkapp_commands ~f:(fun ndx zkapp_command ->
        printf "Processing zkApp %d of %d, account_updates length: %d\n"
          (ndx + 1) num_zkapp_commands
          (List.length @@ Zkapp_command.account_updates_list zkapp_command) ;
        let%bind res =
          Verifier.verify_commands verifier
            [ User_command.to_verifiable ~ledger ~get:Mina_ledger.Ledger.get
                ~location_of_account:Mina_ledger.Ledger.location_of_account
                (Zkapp_command zkapp_command)
            ]
        in
        let _a = Or_error.ok_exn res in
        let tm_zkapp0 = Core.Unix.gettimeofday () in
        (*verify*)
        let%map () =
          match%map
            Async_kernel.Monitor.try_with (fun () ->
                Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn
                  ledger [ zkapp_command ] )
          with
          | Ok () ->
              ()
          | Error exn ->
              (* workaround for SNARK failures *)
              printf !"Error: %s\n%!" (Exn.to_string exn) ;
              printf "zkApp failed, continuing ...\n" ;
              ()
        in
        let tm_zkapp1 = Core.Unix.gettimeofday () in
        let zkapp_span = Time.Span.of_sec (tm_zkapp1 -. tm_zkapp0) in
        printf
          !"Time for zkApp %d: %{Time.Span.to_string_hum}\n"
          (ndx + 1) zkapp_span )
  in
  let tm1 = Core.Unix.gettimeofday () in
  let total_time = Time.Span.of_sec (tm1 -. tm0) in
  format_time_span total_time

let check_base_snarks sparse_ledger0 (transitions : Transaction.Valid.t list)
    preeval =
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  ignore
    ( let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let txn_state_view = Lazy.force curr_state_view in
      List.fold transitions ~init:sparse_ledger0 ~f:(fun sparse_ledger t ->
          let sparse_ledger', applied_transaction =
            Sparse_ledger.apply_transaction ~constraint_constants
              ~txn_state_view sparse_ledger (Transaction.forget t)
            |> Or_error.ok_exn
          in
          let coinbase_stack_target =
            pending_coinbase_stack_target (Transaction.forget t)
              Pending_coinbase.Stack.empty
          in
          let supply_increase =
            Mina_ledger.Ledger.Transaction_applied.supply_increase
              applied_transaction
            |> Or_error.ok_exn
          in
          let () =
            Transaction_snark.check_transaction ?preeval ~constraint_constants
              ~sok_message
              ~source:(Sparse_ledger.merkle_root sparse_ledger)
              ~target:(Sparse_ledger.merkle_root sparse_ledger')
              ~init_stack:Pending_coinbase.Stack.empty
              ~pending_coinbase_stack_state:
                { source = Pending_coinbase.Stack.empty
                ; target = coinbase_stack_target
                }
              ~zkapp_account1:None ~zkapp_account2:None ~supply_increase
              { Transaction_protocol_state.Poly.block_data =
                  Lazy.force state_body
              ; transaction = t
              }
              (unstage (Sparse_ledger.handler sparse_ledger))
          in
          sparse_ledger' )
      : Sparse_ledger.t ) ;
  Async.Deferred.return "Base constraint system satisfied"

let generate_base_snarks_witness sparse_ledger0
    (transitions : Transaction.Valid.t list) preeval =
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  ignore
    ( let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let txn_state_view = Lazy.force curr_state_view in
      List.fold transitions ~init:sparse_ledger0 ~f:(fun sparse_ledger t ->
          let sparse_ledger', applied_transaction =
            Sparse_ledger.apply_transaction ~constraint_constants
              ~txn_state_view sparse_ledger (Transaction.forget t)
            |> Or_error.ok_exn
          in
          let coinbase_stack_target =
            pending_coinbase_stack_target (Transaction.forget t)
              Pending_coinbase.Stack.empty
          in
          let supply_increase =
            Mina_ledger.Ledger.Transaction_applied.supply_increase
              applied_transaction
            |> Or_error.ok_exn
          in
          let () =
            Transaction_snark.generate_transaction_witness ?preeval
              ~constraint_constants ~sok_message
              ~source:(Sparse_ledger.merkle_root sparse_ledger)
              ~target:(Sparse_ledger.merkle_root sparse_ledger')
              ~init_stack:Pending_coinbase.Stack.empty
              ~pending_coinbase_stack_state:
                { Transaction_snark.Pending_coinbase_stack_state.source =
                    Pending_coinbase.Stack.empty
                ; target = coinbase_stack_target
                }
              ~zkapp_account1:None ~zkapp_account2:None ~supply_increase
              { Transaction_protocol_state.Poly.transaction = t
              ; block_data = Lazy.force state_body
              }
              (unstage (Sparse_ledger.handler sparse_ledger))
          in
          sparse_ledger' )
      : Sparse_ledger.t ) ;
  Async.Deferred.return "Base constraint system satisfied"

let run ~user_command_profiler ~zkapp_profiler num_transactions repeats preeval
    use_zkapps : unit =
  let logger = Logger.null () in
  let print n msg = printf !"[%i] %s\n%!" n msg in
  if use_zkapps then (
    let ledger, transactions = create_ledger_and_zkapps num_transactions in
    Parallel.init_master () ;
    let verifier =
      Async.Thread_safe.block_on_async_exn (fun () ->
          Verifier.create ~logger ~proof_level ~constraint_constants
            ~conf_dir:None
            ~pids:(Child_processes.Termination.create_pid_table ()) )
    in
    let rec go n =
      if n <= 0 then ()
      else
        let message =
          Async.Thread_safe.block_on_async_exn (fun () ->
              zkapp_profiler ~verifier ledger transactions )
        in
        print n message ;
        go (n - 1)
    in
    go repeats )
  else
    let ledger, transactions =
      create_ledger_and_transactions num_transactions
    in
    let sparse_ledger =
      Mina_ledger.Sparse_ledger.of_ledger_subset_exn ledger
        (List.fold ~init:[] transactions ~f:(fun participants t ->
             List.rev_append
               (Transaction.accounts_referenced (Transaction.forget t))
               participants ) )
    in
    let rec go n =
      if n <= 0 then ()
      else
        let message =
          Async.Thread_safe.block_on_async_exn (fun () ->
              user_command_profiler sparse_ledger transactions preeval )
        in
        print n message ;
        go (n - 1)
    in
    go repeats

let main num_transactions repeats preeval use_zkapps () =
  Test_util.with_randomness 123456789 (fun () ->
      let module T = Transaction_snark.Make (struct
        let constraint_constants =
          Genesis_constants.Constraint_constants.compiled

        let proof_level = Genesis_constants.Proof_level.Full
      end) in
      run
        ~user_command_profiler:(profile_user_command (module T))
        ~zkapp_profiler:profile_zkapps num_transactions repeats preeval
        use_zkapps )

let dry num_transactions repeats preeval use_zkapps () =
  let zkapp_profiler ~verifier:_ _ _ =
    failwith "Can't check base SNARKs on zkApps"
  in
  Test_util.with_randomness 123456789 (fun () ->
      run ~user_command_profiler:check_base_snarks ~zkapp_profiler
        num_transactions repeats preeval use_zkapps )

let witness num_transactions repeats preeval use_zkapps () =
  let zkapp_profiler ~verifier:_ _ _ =
    failwith "Can't generate witnesses for base SNARKs on zkApps"
  in
  Test_util.with_randomness 123456789 (fun () ->
      run ~user_command_profiler:generate_base_snarks_witness ~zkapp_profiler
        num_transactions repeats preeval use_zkapps )

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler"
    (let%map_open n =
       flag "--k" ~aliases:[ "-k" ]
         ~doc:
           "count count = log_2(number of transactions to snark); omit for \
            mocked transactions; required for zkApps"
         (optional int)
     and repeats =
       flag "--repeat" ~aliases:[ "-repeat" ]
         ~doc:"count number of times to repeat the profile" (optional int)
     and preeval =
       flag "--preeval" ~aliases:[ "-preeval" ]
         ~doc:
           "true/false whether to pre-evaluate the checked computation to \
            cache interpreter and computation state (payments only)"
         (optional bool)
     and check_only =
       flag "--check-only" ~aliases:[ "-check-only" ]
         ~doc:
           "Just check base snarks, don't keys or time anything (payments only)"
         no_arg
     and witness_only =
       flag "--witness-only" ~aliases:[ "-witness-only" ]
         ~doc:"Just generate the witnesses for the base snarks (payments only)"
         no_arg
     and use_zkapps =
       flag "--zkapps" ~aliases:[ "-zkapps" ]
         ~doc:"Use zkApp transactions instead of payments" no_arg
     in
     let num_transactions =
       Option.map n ~f:(fun n -> `Count (Int.pow 2 n))
       |> Option.value ~default:`Two_from_same
     in
     if use_zkapps then (
       let incompatible_flags = ref [] in
       let add_incompatible_flag flag =
         incompatible_flags := flag :: !incompatible_flags
       in
       ( match preeval with
       | None ->
           ()
       | Some b ->
           if b then add_incompatible_flag "--preeval true" ) ;
       if check_only then add_incompatible_flag "--check-only" ;
       if witness_only then add_incompatible_flag "--witness-only" ;
       if not @@ List.is_empty !incompatible_flags then (
         eprintf "These flags are incompatible with --zkapps: %s\n"
           (String.concat !incompatible_flags ~sep:", ") ;
         exit 1 ) ) ;
     let repeats = Option.value repeats ~default:1 in
     if witness_only then witness num_transactions repeats preeval use_zkapps
     else if check_only then dry num_transactions repeats preeval use_zkapps
     else main num_transactions repeats preeval use_zkapps )
