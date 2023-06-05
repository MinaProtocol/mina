(* snark_profiler_lib.ml *)

open Core
open Signature_lib
open Mina_base
open Mina_transaction

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
        ~body:(Payment { receiver_pk = to_pk; amount })
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
    let fee = Currency.Fee.of_nanomina_int_exn (1 + Random.int 100) in
    let amount = Currency.Amount.of_nanomina_int_exn (1 + Random.int 100) in
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
          (Currency.Amount.of_nanomina_int_exn 10)
          Currency.Fee.zero Account.Nonce.zero
      in
      let b =
        txn keys.(0) keys.(1)
          (Currency.Amount.of_nanomina_int_exn 10)
          Currency.Fee.zero
          (Account.Nonce.succ Account.Nonce.zero)
      in
      (ledger, [ Command (Signed_command a); Command (Signed_command b) ])

module Transaction_key = struct
  module T = struct
    type t = { proof_segments : int; signed_single : int; signed_pair : int }
    [@@deriving hash, sexp, compare]
  end

  include Hashtbl.Make (T)

  type t = T.t

  include Comparable.Make (T)
  include Hashable.Make (T)

  let of_zkapp_command ~ledger (p : Zkapp_command.t) =
    let second_pass_ledger =
      let new_mask =
        Mina_ledger.Ledger.Mask.create
          ~depth:(Mina_ledger.Ledger.depth ledger)
          ()
      in
      Mina_ledger.Ledger.register_mask ledger new_mask
    in
    let _partial_stmt =
      Mina_ledger.Ledger.apply_transaction_first_pass ~constraint_constants
        ~global_slot:Mina_numbers.Global_slot_since_genesis.zero
        ~txn_state_view:Transaction_snark_tests.Util.genesis_state_view
        second_pass_ledger
        (Mina_transaction.Transaction.Command (Zkapp_command p))
      |> Or_error.ok_exn
    in
    let segments =
      Transaction_snark.zkapp_command_witnesses_exn ~constraint_constants
        ~global_slot:Mina_numbers.Global_slot_since_genesis.zero
        ~state_body:Transaction_snark_tests.Util.genesis_state_body
        ~fee_excess:Currency.Amount.Signed.zero
        [ ( `Pending_coinbase_init_stack Pending_coinbase.Stack.empty
          , `Pending_coinbase_of_statement
              { Transaction_snark.Pending_coinbase_stack_state.source =
                  Pending_coinbase.Stack.empty
              ; target =
                  Pending_coinbase.Stack.push_state
                    Transaction_snark_tests.Util.genesis_state_body_hash
                    Mina_numbers.Global_slot_since_genesis.zero
                    Pending_coinbase.Stack.empty
              }
          , `Ledger ledger
          , `Ledger second_pass_ledger
          , `Connecting_ledger_hash
              (Mina_ledger.Ledger.merkle_root second_pass_ledger)
          , p )
        ]
    in
    ignore
    @@ Mina_ledger.Ledger.Maskable.unregister_mask_exn ~loc:__LOC__
         second_pass_ledger ;
    List.fold
      ~init:({ proof_segments = 0; signed_single = 0; signed_pair = 0 } : t)
      segments
      ~f:(fun ({ proof_segments; signed_single; signed_pair } as acc)
              (_, segment, _) ->
        match segment with
        | Transaction_snark.Zkapp_command_segment.Basic.Proved ->
            { acc with proof_segments = proof_segments + 1 }
        | Opt_signed ->
            { acc with signed_single = signed_single + 1 }
        | Opt_signed_opt_signed ->
            { acc with signed_pair = signed_pair + 1 } )
end

module Time_values = struct
  type t = { verification_time : Time.Span.t; proving_time : Time.Span.t }
  [@@deriving hash, sexp, compare]

  let empty =
    { verification_time = Time.Span.of_sec 0.
    ; proving_time = Time.Span.of_sec 0.
    }
end

let transaction_combinations = Transaction_key.Table.create ()

let create_ledger_and_zkapps ?(min_num_updates = 1) ?(num_proof_updates = 0)
    ~max_num_updates () : Mina_ledger.Ledger.t * Zkapp_command.t list =
  let `VK verification_key, `Prover prover =
    Transaction_snark.For_tests.create_trivial_snapp ~constraint_constants ()
  in
  let num_keypairs = max_num_updates + 10 in
  let keypairs = List.init num_keypairs ~f:(fun _ -> Keypair.create ()) in
  let num_keypairs_in_ledger = max_num_updates + 1 in
  let keypairs_in_ledger = List.take keypairs num_keypairs_in_ledger in
  let account_ids =
    List.map keypairs_in_ledger ~f:(fun { public_key; _ } ->
        Account_id.create (Public_key.compress public_key) Token_id.default )
  in
  let keymap =
    List.fold ~init:Public_key.Compressed.Map.empty keypairs_in_ledger
      ~f:(fun m kp ->
        Public_key.Compressed.Map.add_exn m
          ~key:(Public_key.compress kp.public_key)
          ~data:kp.private_key )
  in
  let balances =
    let min_cmd_fee = Currency.Fee.minimum_user_command_fee in
    let min_balance =
      Currency.Fee.to_nanomina_int min_cmd_fee
      |> Int.( + ) 1_000_000_000_000_000
      |> Currency.Balance.of_nanomina_int_exn
    in
    (* max balance to avoid overflow when adding deltas *)
    let max_balance =
      let max_bal = Currency.Balance.of_mina_string_exn "10000000.0" in
      match
        Currency.Balance.add_amount min_balance
          (Currency.Balance.to_amount max_bal)
      with
      | None ->
          failwith "parties_with_ledger: overflow for max_balance"
      | Some _ ->
          max_bal
    in
    Quickcheck.random_value
      (Quickcheck.Generator.list_with_length num_keypairs_in_ledger
         (Currency.Balance.gen_incl min_balance max_balance) )
  in
  let account_ids_and_balances = List.zip_exn account_ids balances in
  let snappify_account (account : Account.t) : Account.t =
    (* TODO: use real keys *)
    let permissions =
      { Permissions.user_default with
        edit_state = Permissions.Auth_required.Either
      ; send = Either
      ; set_delegate = Either
      ; set_permissions = Either
      ; set_verification_key = Either
      ; set_zkapp_uri = Either
      ; edit_action_state = Either
      ; set_token_symbol = Either
      ; increment_nonce = Either
      ; set_voting_for = Either
      }
    in
    let verification_key = Some verification_key in
    let zkapp = Some { Zkapp_account.default with verification_key } in
    { account with permissions; zkapp }
  in
  (* half zkApp accounts, half non-zkApp accounts *)
  let accounts =
    List.map account_ids_and_balances ~f:(fun (account_id, balance) ->
        let account = Account.create account_id balance in
        snappify_account account )
  in
  let fee_payer_keypair = List.hd_exn keypairs in
  let fee_payer_pk = Public_key.compress fee_payer_keypair.public_key in
  let ledger =
    Mina_ledger.Ledger.create ~depth:constraint_constants.ledger_depth ()
  in
  List.iter2_exn account_ids accounts ~f:(fun acct_id acct ->
      match Mina_ledger.Ledger.get_or_create_account ledger acct_id acct with
      | Error err ->
          failwithf
            "parties: error adding account for account id: %s, error: %s@."
            (Account_id.to_yojson acct_id |> Yojson.Safe.to_string)
            (Error.to_string_hum err) ()
      | Ok (`Existed, _) ->
          failwithf "parties: account for account id already exists: %s@."
            (Account_id.to_yojson acct_id |> Yojson.Safe.to_string)
            ()
      | Ok (`Added, _) ->
          () ) ;
  let field_array_list_gen ~array_len ~list_len =
    let open Quickcheck.Generator.Let_syntax in
    let array_gen =
      let%map fields =
        Quickcheck.Generator.list_with_length array_len
          Snark_params.Tick.Field.gen
      in
      Array.of_list fields
    in
    Quickcheck.Generator.list_with_length list_len array_gen
  in
  let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
  let actions =
    Quickcheck.random_value (field_array_list_gen ~array_len:1 ~list_len:2)
  in
  let snapp_update =
    { Account_update.Update.dummy with
      app_state =
        Pickles_types.Vector.init Zkapp_state.Max_state_size.n ~f:(fun i ->
            Zkapp_basic.Set_or_keep.Set (Snark_params.Tick.Field.of_int i) )
    }
  in
  let amount = Currency.Amount.of_nanomina_int_exn 1_000_000_000 in
  let sender_parties = 1 in
  let test_spec nonce ~num_updates ~num_proof_updates :
      bool * Transaction_snark.For_tests.Update_states_spec.t =
    let receiver_count =
      max 0 (num_updates - num_proof_updates - sender_parties)
    in
    (* if there's space for only one more then just make a no-op update*)
    let empty_sender = num_updates - num_proof_updates = 1 in
    ( empty_sender
    , { sender = (fee_payer_keypair, nonce)
      ; fee
      ; fee_payer = None
      ; receivers =
          List.map (List.take keypairs_in_ledger receiver_count) ~f:(fun kp ->
              (kp, amount) )
      ; amount =
          ( if receiver_count > 0 then
            Currency.Amount.scale amount receiver_count |> Option.value_exn
          else Currency.Amount.zero )
      ; zkapp_account_keypairs = List.take keypairs_in_ledger num_proof_updates
      ; memo = Signed_command_memo.create_from_string_exn "blah"
      ; new_zkapp_account = false
      ; snapp_update
      ; current_auth = Permissions.Auth_required.Proof
      ; call_data = Snark_params.Tick.Field.zero
      ; events = []
      ; actions
      ; preconditions = None
      } )
  in
  let rec permute proof_parties non_proof_parties current_perm acc =
    match (proof_parties, non_proof_parties) with
    | [], [] ->
        List.rev current_perm :: acc
    | [], _ ->
        List.rev (List.rev non_proof_parties @ current_perm) :: acc
    | _, [] ->
        List.rev (List.rev proof_parties @ current_perm) :: acc
    | p :: ps, np :: nps ->
        let perm1 = permute ps non_proof_parties (p :: current_perm) acc in
        let perm2 = permute proof_parties nps (np :: current_perm) acc in
        perm1 @ perm2
  in
  let rec generate_zkapp ~num_proof_updates ~num_updates acc nonce =
    if num_updates > max_num_updates then List.rev acc
    else if num_proof_updates > num_updates then
      (* start a new iteration for transactions with one more update *)
      generate_zkapp ~num_proof_updates:0 ~num_updates:(num_updates + 1) acc
        nonce
    else
      let start = Time.now () in
      let empty_sender, spec =
        test_spec nonce ~num_proof_updates ~num_updates
      in
      let parties =
        Async.Thread_safe.block_on_async_exn (fun () ->
            Transaction_snark.For_tests.update_states
              ~zkapp_prover_and_vk:(prover, verification_key)
              ~constraint_constants ~empty_sender spec
              ~receiver_auth:Control.Tag.Signature )
      in
      let simple_parties = Zkapp_command.to_simple parties in
      let other_parties = simple_parties.account_updates in
      let proof_parties, signature_parties, no_auths, _next_nonce =
        List.fold ~init:([], [], [], nonce) other_parties
          ~f:(fun (pc, sc, na, nonce) (p : Account_update.Simple.t) ->
            let nonce =
              if
                Public_key.Compressed.equal p.body.public_key fee_payer_pk
                && p.body.increment_nonce
              then Mina_base.Account.Nonce.succ nonce
              else nonce
            in
            match p.authorization with
            | Proof _ ->
                (p :: pc, sc, na, nonce)
            | Signature _ ->
                (pc, p :: sc, na, nonce)
            | _ ->
                (pc, sc, p :: na, nonce) )
      in
      printf
        !"\n\n\
          Generated zkapp transactions with %d updates and %d proof updates in \
          %f secs\n\
          %!"
        (List.length other_parties + 1)
        (List.length proof_parties)
        Time.(Span.to_sec (diff (now ()) start)) ;
      let permutations =
        permute proof_parties (signature_parties @ no_auths) [] []
        |> List.filter_mapi
             ~f:(fun i (account_updates : Account_update.Simple.t list) ->
               let p =
                 Zkapp_command.of_simple { simple_parties with account_updates }
               in
               let combination = Transaction_key.of_zkapp_command ~ledger p in
               let perm_string =
                 List.fold ~init:"S" account_updates
                   ~f:(fun acc (p : Account_update.Simple.t) ->
                     match p.authorization with
                     | Proof _ ->
                         acc ^ "P"
                     | Signature _ ->
                         acc ^ "S"
                     | None_given ->
                         acc ^ "N" )
               in
               if Transaction_key.Table.mem transaction_combinations combination
               then (
                 printf "Skipping %s\n%!" perm_string ;
                 None )
               else (
                 printf
                   !"Generated updates permutation %d: %s\n\
                     Updating authorizations...\n\
                     %!"
                   i perm_string ;
                 (*Update the authorizations*)
                 let p =
                   Async.Thread_safe.block_on_async_exn (fun () ->
                       Zkapp_command_builder.replace_authorizations ~prover
                         ~keymap p )
                 in
                 Transaction_key.Table.add_exn transaction_combinations
                   ~key:combination
                   ~data:(p, Time_values.empty, perm_string) ;
                 Some p ) )
      in
      generate_zkapp ~num_proof_updates:(num_proof_updates + 1) ~num_updates
        (permutations @ acc) nonce
  in
  ( ledger
  , generate_zkapp ~num_proof_updates ~num_updates:min_num_updates []
      Mina_base.Account.Nonce.zero )

let _create_ledger_and_zkapps_from_generator num_transactions :
    Mina_ledger.Ledger.t * Zkapp_command.t list =
  let length =
    match num_transactions with
    | `Count length ->
        length
    | `Two_from_same ->
        failwith "Must provide a count when profiling with snapps"
  in
  let max_account_updates = 6 in
  printf
    !"Generating zkApp transactions with %d updates\n%!"
    max_account_updates ;
  let start = Time.now () in
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
        | User_command.Zkapp_command parties_valid ->
            let parties = Zkapp_command.Valid.forget parties_valid in
            let other_parties = Zkapp_command.account_updates_list parties in
            let proof_count, signature_count, no_auths =
              List.fold ~init:(0, 0, 0)
                (Account_update.of_fee_payer parties.fee_payer :: other_parties)
                ~f:(fun (pc, sc, na) (p : Account_update.t) ->
                  match p.authorization with
                  | Proof _ ->
                      (pc + 1, sc, na)
                  | Signature _ ->
                      (pc, sc + 1, na)
                  | _ ->
                      (pc, sc, na + 1) )
            in
            printf
              !"Generated zkapp with %d parties of which %d signatures, %d \
                proofs and %d none\n\
                %!"
              (List.length other_parties + 1)
              signature_count proof_count no_auths ;
            Async.Thread_safe.block_on_async_exn (fun () ->
                Zkapp_command_builder.replace_authorizations
                  ~prover (*~dummy_proof:proof*)
                  ~keymap
                  (Zkapp_command.Valid.forget parties_valid) )
        | User_command.Signed_command _ ->
            failwith "Expected Zkapp_command user command" )
  in
  printf
    !"Time to generate zkapps: %f secs\n%!"
    Time.(Span.to_sec (diff (now ()) start)) ;
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
    Pending_coinbase.Stack.(
      push_state
        (Lazy.force state_body_hash)
        (Lazy.force curr_state_view).global_slot_since_genesis stack)
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

let apply_transactions_and_keep_intermediate_ledgers
    ~(txn_state_view : Zkapp_precondition.Protocol_state.View.t)
    first_pass_ledger txns =
  let first_pass_target_ledgers, partially_applied_txns =
    List.fold_map txns ~init:first_pass_ledger ~f:(fun l txn ->
        let l', txn' =
          Transaction.forget txn
          |> Sparse_ledger.apply_transaction_first_pass ~constraint_constants
               ~global_slot:txn_state_view.global_slot_since_genesis
               ~txn_state_view l
          |> Or_error.ok_exn
        in
        (l', (l', txn')) )
    |> snd |> List.unzip
  in
  let second_pass_target_ledgers, applied_txns =
    let second_pass_ledger = List.last_exn first_pass_target_ledgers in
    List.fold_map partially_applied_txns ~init:second_pass_ledger
      ~f:(fun l txn ->
        let l', txn' =
          Sparse_ledger.apply_transaction_second_pass l txn |> Or_error.ok_exn
        in
        (l', (l', txn')) )
    |> snd |> List.unzip
  in
  (first_pass_target_ledgers, second_pass_target_ledgers, applied_txns)

(* This gives the "wall-clock time" to snarkify the given list of transactions, assuming
   unbounded parallelism. *)
let profile_user_command (module T : Transaction_snark.S) sparse_ledger0
    (transitions : Transaction.Valid.t list) _ : string Async.Deferred.t =
  let txn_state_view = Lazy.force curr_state_view in
  let open Async.Deferred.Let_syntax in
  let first_pass_target_ledgers, second_pass_target_ledgers, applied_txns =
    apply_transactions_and_keep_intermediate_ledgers ~txn_state_view
      sparse_ledger0 transitions
  in
  let final_first_pass_ledger =
    Sparse_ledger.merkle_root (List.last_exn first_pass_target_ledgers)
  in
  List.iter second_pass_target_ledgers ~f:(fun l ->
      assert (
        Ledger_hash.equal (Sparse_ledger.merkle_root l) final_first_pass_ledger ) ) ;
  let%bind (base_proof_time, _, _), base_proofs_rev =
    List.zip_exn first_pass_target_ledgers applied_txns
    |> Async.Deferred.List.fold
         ~init:
           ((Time.Span.zero, sparse_ledger0, Pending_coinbase.Stack.empty), [])
         ~f:(fun ((max_span, source_ledger, coinbase_stack_source), proofs)
                 (target_ledger, applied) ->
           let txn =
             With_status.data
             @@ Mina_ledger.Ledger.Transaction_applied.transaction applied
           in
           (* the txn was already valid before apply, we are just recasting it here after application *)
           let (`If_this_is_used_it_should_have_a_comment_justifying_it
                 valid_txn ) =
             Transaction.to_valid_unsafe txn
           in
           let coinbase_stack_target =
             pending_coinbase_stack_target txn coinbase_stack_source
           in
           let tm0 = Core.Unix.gettimeofday () in
           let target_hash = Sparse_ledger.merkle_root target_ledger in
           let%map proof =
             T.of_non_zkapp_command_transaction
               ~statement:
                 { sok_digest = Sok_message.Digest.default
                 ; source =
                     { first_pass_ledger =
                         Sparse_ledger.merkle_root source_ledger
                     ; second_pass_ledger = target_hash
                     ; pending_coinbase_stack = coinbase_stack_source
                     ; local_state = Mina_state.Local_state.empty ()
                     }
                 ; target =
                     { first_pass_ledger = target_hash
                     ; second_pass_ledger = target_hash
                     ; pending_coinbase_stack = coinbase_stack_target
                     ; local_state = Mina_state.Local_state.empty ()
                     }
                 ; connecting_ledger_left = target_hash
                 ; connecting_ledger_right = target_hash
                 ; supply_increase =
                     (let magnitude =
                        Transaction.expected_supply_increase txn
                        |> Or_error.ok_exn
                      in
                      let sgn = Sgn.Pos in
                      Currency.Amount.Signed.create ~magnitude ~sgn )
                 ; fee_excess = Transaction.fee_excess txn |> Or_error.ok_exn
                 }
               ~init_stack:coinbase_stack_source
               { Transaction_protocol_state.Poly.transaction = valid_txn
               ; block_data = Lazy.force state_body
               ; global_slot = txn_state_view.global_slot_since_genesis
               }
               (unstage (Sparse_ledger.handler source_ledger))
           in
           let tm1 = Core.Unix.gettimeofday () in
           let span = Time.Span.of_sec (tm1 -. tm0) in
           ( (Time.Span.max span max_span, target_ledger, coinbase_stack_target)
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
        let account_updates =
          Zkapp_command.account_updates_list zkapp_command
        in
        printf "Processing zkApp %d of %d, other_parties length: %d\n" (ndx + 1)
          num_zkapp_commands
          (List.length account_updates) ;
        let v_start_time = Time.now () in
        let%bind res =
          Verifier.verify_commands verifier
            [ { With_status.data =
                  User_command.to_verifiable ~status:Applied
                    ~find_vk:
                      (Zkapp_command.Verifiable.find_vk_via_ledger ~ledger
                         ~get:Mina_ledger.Ledger.get
                         ~location_of_account:
                           Mina_ledger.Ledger.location_of_account )
                    (Zkapp_command zkapp_command)
                  |> Or_error.ok_exn
              ; status = Applied
              }
            ]
        in
        let proof_count, signature_count =
          List.fold ~init:(0, 0)
            ( Account_update.of_fee_payer zkapp_command.fee_payer
            :: account_updates ) ~f:(fun (pc, sc) (p : Account_update.t) ->
              match p.authorization with
              | Proof _ ->
                  (pc + 1, sc)
              | Signature _ ->
                  (pc, sc + 1)
              | _ ->
                  (pc, sc) )
        in
        let verification_time = Time.(diff (now ()) v_start_time) in
        printf
          !"Verifying zkapp with %d signatures and %d proofs took %f secs\n%!"
          signature_count proof_count
          (Time.Span.to_sec verification_time) ;
        let _a = Or_error.ok_exn res in
        let tm_zkapp0 = Core.Unix.gettimeofday () in
        (*verify*)
        let%map () =
          match%map
            Async_kernel.Monitor.try_with (fun () ->
                Transaction_snark_tests.Util.check_zkapp_command_with_merges_exn
                  ~ignore_outside_snark:true ledger [ zkapp_command ] )
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
        let time_values =
          { Time_values.verification_time; proving_time = zkapp_span }
        in
        let combination =
          Transaction_key.of_zkapp_command ~ledger zkapp_command
        in
        Transaction_key.Table.change transaction_combinations combination
          ~f:(fun data_opt ->
            let txn, _, perm_string = Option.value_exn data_opt in
            Some (txn, time_values, perm_string) ) ;
        printf
          !"Time for zkApp %d: %{Time.Span.to_string_hum}\n"
          (ndx + 1) zkapp_span )
  in
  printf
    "| No.| Proof updates| Non-proof pairs| Non-proof singles| Mempool \
     verification time (sec)| Transaction proving time (sec)|Permutation|\n\
    \ |--|--|--|--|--|--|--|\n" ;
  List.iteri
    ( Transaction_key.Table.to_alist transaction_combinations
    |> List.sort ~compare:(fun (k1, _) (k2, _) ->
           let total_updates (k : Transaction_key.t) =
             k.proof_segments + (2 * k.signed_pair) + k.signed_single
           in
           let total_compare =
             Int.compare (total_updates k1) (total_updates k2)
           in
           let proof_compare =
             Int.compare k1.proof_segments k2.proof_segments
           in
           let signed_pair_compare =
             Int.compare k1.signed_pair k2.signed_pair
           in
           if total_compare <> 0 then total_compare
           else if proof_compare <> 0 then proof_compare
           else signed_pair_compare ) )
    ~f:(fun i (k, (_, t, perm)) ->
      printf "| %d| %d| %d| %d| %f| %f| %s|\n" (i + 1) k.proof_segments
        k.signed_pair k.signed_single
        (Time.Span.to_sec t.verification_time)
        (Time.Span.to_sec t.proving_time)
        perm ) ;
  let tm1 = Core.Unix.gettimeofday () in
  let total_time = Time.Span.of_sec (tm1 -. tm0) in
  format_time_span total_time

let check_base_snarks sparse_ledger0 (transitions : Transaction.Valid.t list)
    preeval =
  ignore
    ( let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let txn_state_view = Lazy.force curr_state_view in
      let first_pass_target_ledgers, _, applied_txns =
        apply_transactions_and_keep_intermediate_ledgers ~txn_state_view
          sparse_ledger0 transitions
      in
      List.zip_exn first_pass_target_ledgers applied_txns
      |> List.fold ~init:sparse_ledger0
           ~f:(fun source_ledger (target_ledger, applied_txn) ->
             let txn =
               With_status.data
               @@ Mina_ledger.Ledger.Transaction_applied.transaction applied_txn
             in
             (* the txn was already valid before apply, we are just recasting it here after application *)
             let (`If_this_is_used_it_should_have_a_comment_justifying_it
                   valid_txn ) =
               Transaction.to_valid_unsafe txn
             in
             let coinbase_stack_target =
               pending_coinbase_stack_target txn Pending_coinbase.Stack.empty
             in
             let supply_increase =
               Mina_ledger.Ledger.Transaction_applied.supply_increase
                 applied_txn
               |> Or_error.ok_exn
             in
             let () =
               Transaction_snark.check_transaction ?preeval
                 ~constraint_constants ~sok_message
                 ~source_first_pass_ledger:
                   (Sparse_ledger.merkle_root source_ledger)
                 ~target_first_pass_ledger:
                   (Sparse_ledger.merkle_root target_ledger)
                 ~init_stack:Pending_coinbase.Stack.empty
                 ~pending_coinbase_stack_state:
                   { source = Pending_coinbase.Stack.empty
                   ; target = coinbase_stack_target
                   }
                 ~supply_increase
                 { Transaction_protocol_state.Poly.block_data =
                     Lazy.force state_body
                 ; transaction = valid_txn
                 ; global_slot = txn_state_view.global_slot_since_genesis
                 }
                 (unstage (Sparse_ledger.handler source_ledger))
             in
             target_ledger )
      : Sparse_ledger.t ) ;
  Async.Deferred.return "Base constraint system satisfied"

let generate_base_snarks_witness sparse_ledger0
    (transitions : Transaction.Valid.t list) preeval =
  ignore
    ( let sok_message =
        Sok_message.create ~fee:Currency.Fee.zero
          ~prover:
            Public_key.(compress (of_private_key_exn (Private_key.create ())))
      in
      let txn_state_view = Lazy.force curr_state_view in
      let first_pass_target_ledgers, _, applied_txns =
        apply_transactions_and_keep_intermediate_ledgers ~txn_state_view
          sparse_ledger0 transitions
      in
      List.zip_exn first_pass_target_ledgers applied_txns
      |> List.fold ~init:sparse_ledger0
           ~f:(fun source_ledger (target_ledger, applied_txn) ->
             let txn =
               With_status.data
               @@ Mina_ledger.Ledger.Transaction_applied.transaction applied_txn
             in
             (* the txn was already valid before apply, we are just recasting it here after application *)
             let (`If_this_is_used_it_should_have_a_comment_justifying_it
                   valid_txn ) =
               Transaction.to_valid_unsafe txn
             in
             let coinbase_stack_target =
               pending_coinbase_stack_target txn Pending_coinbase.Stack.empty
             in
             let supply_increase =
               Mina_ledger.Ledger.Transaction_applied.supply_increase
                 applied_txn
               |> Or_error.ok_exn
             in
             let () =
               Transaction_snark.generate_transaction_witness ?preeval
                 ~constraint_constants ~sok_message
                 ~source_first_pass_ledger:
                   (Sparse_ledger.merkle_root source_ledger)
                 ~target_first_pass_ledger:
                   (Sparse_ledger.merkle_root target_ledger)
                 ~init_stack:Pending_coinbase.Stack.empty
                 ~pending_coinbase_stack_state:
                   { Transaction_snark.Pending_coinbase_stack_state.source =
                       Pending_coinbase.Stack.empty
                   ; target = coinbase_stack_target
                   }
                 ~supply_increase
                 { Transaction_protocol_state.Poly.transaction = valid_txn
                 ; block_data = Lazy.force state_body
                 ; global_slot = txn_state_view.global_slot_since_genesis
                 }
                 (unstage (Sparse_ledger.handler source_ledger))
             in
             target_ledger )
      : Sparse_ledger.t ) ;
  Async.Deferred.return "Base constraint system satisfied"
