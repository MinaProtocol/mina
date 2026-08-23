(* Benchmark for transaction validation (block-packing) cost.

   Applies a mix of payments the way block production validates candidates:
   valid ones, ones rejected for their nonce, ones rejected for their
   balance, and ones that create the receiving account. Each is applied into
   a mask that is committed only on success -- what the transaction validator
   does -- once over a real ledger and once over a ledger that maintains no
   merkle hashes, over both an in-memory and a RocksDB-backed base ledger.
   The two are checked to agree on every accept/reject answer, every
   transaction status and every resulting account.

   Two mixes are run: one where almost every payment updates accounts that
   already exist, and one where almost every payment creates the account it
   pays, since those are different paths through the ledger. *)

open Core
open Mina_base
module Ledger = Mina_ledger.Ledger
module Non_hashing_ledger = Ledger.Non_hashing_ledger

let constraint_constants =
  Genesis_constants.For_unit_tests.Constraint_constants.t

let signature_kind = Mina_signature_kind.Testnet

let global_slot = Mina_numbers.Global_slot_since_genesis.of_int 5

(* Only used to fill the [txn_state_view] argument; payments ignore it. *)
let txn_state_view : Zkapp_precondition.Protocol_state.View.t =
  let h = Frozen_ledger_hash.empty_hash in
  let len = Mina_numbers.Length.zero in
  let a = Currency.Amount.zero in
  let epoch_data =
    { Epoch_data.Poly.ledger =
        { Epoch_ledger.Poly.hash = h; total_currency = a }
    ; seed = h
    ; start_checkpoint = h
    ; lock_checkpoint = h
    ; epoch_length = len
    }
  in
  { snarked_ledger_hash = h
  ; blockchain_length = len
  ; min_window_density = len
  ; total_currency = a
  ; global_slot_since_genesis = global_slot
  ; staking_epoch_data = epoch_data
  ; next_epoch_data = epoch_data
  }

let keypairs_from ~offset n =
  Array.init n ~f:(fun i ->
      Quickcheck.random_value
        ~seed:(`Deterministic (sprintf "hashless-bench-%d" (offset + i)))
        Signature_lib.Keypair.gen )

let keypairs n = keypairs_from ~offset:0 n

let populate ledger keys =
  Array.iter keys ~f:(fun (kp : Signature_lib.Keypair.t) ->
      let pk = Signature_lib.Public_key.compress kp.public_key in
      let aid = Account_id.create pk Token_id.default in
      let account =
        Account.create aid (Currency.Balance.of_mina_int_exn 1_000_000)
      in
      Ledger.create_new_account_exn ledger aid account )

(* A mix of transactions that succeed, transactions that fail in each of the
   ways the validator has to distinguish, and payments that create a new
   account (the receiver is a key that was never funded). *)
let payments ~n_txns ~creating keys unfunded =
  let n = Array.length keys in
  let nonces = Array.create ~len:n 0 in
  List.init n_txns ~f:Fn.id
  |> List.map ~f:(fun i ->
         let s = i % n in
         let r = (i + 1 + (i / n)) % n in
         let sender : Signature_lib.Keypair.t = keys.(s) in
         let sender_pk = Signature_lib.Public_key.compress sender.public_key in
         let kind = if i % 8 = 0 then i / 8 % 4 else 0 in
         let receiver_pk =
           if creating || kind = 3 then
             Signature_lib.Public_key.compress
               unfunded.(i % Array.length unfunded)
                 .Signature_lib.Keypair.public_key
           else
             Signature_lib.Public_key.compress
               keys.(r).Signature_lib.Keypair.public_key
         in
         let nonce =
           Mina_numbers.Account_nonce.of_int
             (if kind = 1 then nonces.(s) + 7 else nonces.(s))
         in
         if kind <> 1 && kind <> 2 then nonces.(s) <- nonces.(s) + 1 ;
         let amount =
           if kind = 2 then Currency.Amount.of_mina_int_exn 100_000_000
           else Currency.Amount.of_mina_int_exn 10
         in
         let payload =
           Signed_command_payload.create
             ~fee:(Currency.Fee.of_mina_int_exn 1)
             ~fee_payer_pk:sender_pk ~nonce ~valid_until:None
             ~memo:Signed_command_memo.dummy
             ~body:(Signed_command_payload.Body.Payment { receiver_pk; amount })
         in
         let cmd : Signed_command.t =
           { payload; signer = sender.public_key; signature = Signature.dummy }
         in
         Mina_transaction.Transaction.Command (User_command.Signed_command cmd) )

let apply l txn =
  Ledger.apply_transaction_first_pass ~signature_kind l ~constraint_constants
    ~global_slot ~txn_state_view txn

let apply_non_hashing l txn =
  Non_hashing_ledger.apply_transaction_first_pass ~signature_kind l
    ~constraint_constants ~global_slot ~txn_state_view txn

(* Everything a validation caller can observe: the accept/reject answer, and
   the resulting transaction status. The [previous_hash] carried by the result
   is deliberately excluded: no caller of the validator reads it. *)
let accepted status =
  "accept: " ^ Yojson.Safe.to_string (Transaction_status.to_yojson status)

let rejected e = "reject: " ^ Error.to_string_hum e

let outcome = function
  | Error e ->
      (false, rejected e)
  | Ok (Ledger.Transaction_partially_applied.Signed_command { applied; _ }) ->
      (true, accepted applied.common.user_command.With_status.status)
  | Ok _ ->
      (true, "accept: non-payment")

let outcome_non_hashing = function
  | Error e ->
      (false, rejected e)
  | Ok
      (Non_hashing_ledger.Transaction_partially_applied.Signed_command
        { applied; _ } ) ->
      (true, accepted applied.common.user_command.With_status.status)
  | Ok _ ->
      (true, "accept: non-payment")

(* A shape is set up once over the throwaway ledger, then applies each
   transaction; afterwards it reports the accounts it ended up with, wherever
   it happens to have kept them. *)
type shape =
  { apply : Mina_transaction.Transaction.t -> bool * string
  ; accounts : Signature_lib.Keypair.t array -> string list
  }

let describe_account = function
  | None ->
      "-"
  | Some (a : Account.t) ->
      sprintf "%s/%s"
        (Currency.Balance.to_string a.balance)
        (Mina_numbers.Account_nonce.to_string a.nonce)

let account_id (kp : Signature_lib.Keypair.t) =
  Account_id.create
    (Signature_lib.Public_key.compress kp.public_key)
    Token_id.default

(* What the validator does, over the real ledger: apply each transaction into
   a mask registered over it, and commit that mask only if the transaction was
   accepted. *)
let over_real_ledger l =
  { apply =
      (fun txn ->
        let mask =
          Ledger.register_mask l (Ledger.Mask.create ~depth:(Ledger.depth l) ())
        in
        let r = apply mask txn in
        if Result.is_ok r then Ledger.commit mask ;
        ignore
          (Ledger.unregister_mask_exn ~loc:__LOC__ mask : Ledger.unattached_mask) ;
        outcome r )
  ; accounts =
      (fun keys ->
        Array.to_list keys
        |> List.map ~f:(fun kp ->
               describe_account
                 (Option.bind
                    (Ledger.location_of_account l (account_id kp))
                    ~f:(Ledger.get l) ) ) )
  }

(* The same, over a ledger that maintains no merkle hashes. *)
let over_non_hashing_ledger l =
  let nl = Non_hashing_ledger.of_ledger l in
  { apply =
      (fun txn ->
        let mask =
          Non_hashing_ledger.register_mask nl
            (Non_hashing_ledger.create_mask nl)
        in
        let r = apply_non_hashing mask txn in
        if Result.is_ok r then Non_hashing_ledger.commit mask ;
        ignore
          ( Non_hashing_ledger.unregister_mask_exn ~loc:__LOC__ mask
            : Non_hashing_ledger.unattached_mask ) ;
        outcome_non_hashing r )
  ; accounts =
      (fun keys ->
        Array.to_list keys
        |> List.map ~f:(fun kp ->
               describe_account
                 (Option.bind
                    (Non_hashing_ledger.location_of_account nl (account_id kp))
                    ~f:(Non_hashing_ledger.get nl) ) ) )
  }

let time f =
  let t0 = Time_ns.now () in
  let r = f () in
  (r, Time_ns.Span.to_ms (Time_ns.diff (Time_ns.now ()) t0))

let run_case ~name ~depth ~base ~shape ~txns ~keys =
  let throwaway = Ledger.register_mask base (Ledger.Mask.create ~depth ()) in
  let { apply; accounts } = shape throwaway in
  let results = ref [] in
  let (n_ok, n_err), ms =
    time (fun () ->
        List.fold txns ~init:(0, 0) ~f:(fun (ok, err) txn ->
            let is_ok, description = apply txn in
            results := description :: !results ;
            if is_ok then (ok + 1, err) else (ok, err + 1) ) )
  in
  let accounts = accounts keys in
  ignore
    (Ledger.unregister_mask_exn ~loc:__LOC__ throwaway : Ledger.unattached_mask) ;
  printf "%-38s  %8.1f ms  %7.3f ms/txn  (ok %d, err %d)\n%!" name ms
    (ms /. float_of_int (List.length txns))
    n_ok n_err ;
  (List.rev !results, accounts)

let main ~depth ~n_accounts ~n_txns ~with_db =
  let keys = keypairs n_accounts in
  (* Enough never-funded keys that a creation-heavy run can give every payment
     a receiver of its own. *)
  let unfunded = keypairs_from ~offset:n_accounts n_txns in
  (* Include the never-funded keys, so that accounts created during a run are
     compared as well as accounts updated. *)
  let keys_to_check = Array.append keys unfunded in
  let go ~label ~mix ~txns base =
    printf "\n== depth %d, %d accounts, %d payments (%s), base = %s\n" depth
      n_accounts n_txns mix label ;
    let run = run_case ~depth ~base ~txns ~keys:keys_to_check in
    let a = run ~name:"real ledger" ~shape:over_real_ledger in
    let b = run ~name:"non-hashing ledger" ~shape:over_non_hashing_ledger in
    let check name (x : string list * string list) =
      let outcomes_same = List.equal String.equal (fst a) (fst x) in
      let accounts_same = List.equal String.equal (snd a) (snd x) in
      printf "  %-36s outcomes %s, accounts %s\n%!" name
        (if outcomes_same then "identical" else "DIFFER")
        (if accounts_same then "identical" else "DIFFER") ;
      if not (outcomes_same && accounts_same) then (
        List.iter2_exn (fst a) (fst x) ~f:(fun l r ->
            if not (String.equal l r) then printf "    %s\n    %s\n" l r ) ;
        failwith "mismatch" )
    in
    check "vs non-hashing ledger" b ;
    printf "  accounts created during the run: %d\n%!"
      ( List.count (snd a) ~f:(fun s -> not (String.equal s "-"))
      - Array.length keys )
  in
  let go ~label base =
    go ~label ~mix:"updates to existing accounts"
      ~txns:(payments ~n_txns ~creating:false keys unfunded)
      base ;
    go ~label ~mix:"each to a new receiver"
      ~txns:(payments ~n_txns ~creating:true keys unfunded)
      base
  in
  (* In-memory base: no disk at all below the validating mask. *)
  let ephemeral = Ledger.create_ephemeral ~depth () in
  populate ephemeral keys ;
  go ~label:"ephemeral (in-memory)" ephemeral ;
  if with_db then (
    let dir = Filename.temp_dir "hashless-bench" "" in
    let db = Ledger.create ~directory_name:dir ~depth () in
    populate db keys ;
    (* Flush the accounts and hashes down to RocksDB so that reads from the
       validating mask actually fault through to disk. *)
    Ledger.commit db ;
    go ~label:"rocksdb-backed" db ;
    Ledger.close db )

let () =
  Command_unix.run
  @@ Command.basic ~summary:"validation hashing benchmark"
       (let%map_open.Command depth =
          flag "-depth" (optional_with_default 35 int) ~doc:"N ledger depth"
        and n_accounts =
          flag "-accounts"
            (optional_with_default 256 int)
            ~doc:"N number of accounts"
        and n_txns =
          flag "-txns" (optional_with_default 1024 int) ~doc:"N number of txns"
        and with_db =
          flag "-db" no_arg ~doc:" also benchmark over a RocksDB base ledger"
        in
        fun () -> main ~depth ~n_accounts ~n_txns ~with_db )
