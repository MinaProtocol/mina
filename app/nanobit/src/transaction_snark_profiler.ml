open Core
open Nanobit_base
open Snark_params

let create_ledger_and_transactions num_transactions =
  let open Tick in
  let num_accounts = 4 in
  let nonces = Int.Table.create () in
  let ledger = Ledger.create () in
  let keys = Array.init num_accounts ~f:(fun _ -> Signature_keypair.create ()) in
  Array.iter keys ~f:(fun k ->
    let public_key = Public_key.compress k.public_key in
    Ledger.update ledger public_key
      { public_key; balance = Currency.Balance.of_int 10_000; nonce = Account.Nonce.zero });

  let txn from_kp (to_kp : Signature_keypair.t) amount nonce =
    let payload : Transaction.Payload.t =
      { receiver = Public_key.compress to_kp.public_key
      ; fee = Currency.Fee.zero
      ; amount
      ; nonce
      }
    in
    Transaction.sign from_kp payload
  in

  let random_transaction () : Transaction.With_valid_signature.t =
    let sender_idx = Random.int num_accounts in
    let sender = keys.(sender_idx) in
    let receiver = keys.(Random.int num_accounts) in
    let nonce =
      match Int.Table.find nonces sender_idx with
      | None ->
          let n' = Account.Nonce.zero in
          Int.Table.set nonces ~key:sender_idx ~data:n';
          n'
      | Some n ->
          let n' = Account.Nonce.succ n in
          Int.Table.set nonces ~key:sender_idx ~data:n';
          n'
    in
    txn sender receiver (Currency.Amount.of_int (1 + Random.int 100)) nonce
  in
  match num_transactions with
  | `Count n ->
    (ledger, List.init n (fun _ -> random_transaction ()))
  | `Two_from_same ->
    let a = txn keys.(0) keys.(1) (Currency.Amount.of_int 10) Account.Nonce.zero in
    let b = txn keys.(0) keys.(1) (Currency.Amount.of_int 10) (Account.Nonce.succ (Account.Nonce.zero)) in
    (ledger, [a ; b])

let time thunk =
  let start = Time.now () in
  let x = thunk () in
  let stop = Time.now () in
  (Time.diff stop start, x)

let rec pair_up = function
  | [] -> []
  | x :: y :: xs -> (x, y) :: pair_up xs
  | _ -> failwith "Expected even length list"

(* This gives the "wall-clock time" to snarkify the given list of transactions, assuming
   unbounded parallelism. *)
let profile (module T : Transaction_snark.S) sparse_ledger0 (transactions : Transaction.With_valid_signature.t list) =
  let module Sparse_ledger = Bundle.Sparse_ledger in
  let (base_proof_time, _), base_proofs =
    List.fold_map transactions ~init:(Time.Span.zero, sparse_ledger0) ~f:(fun (max_span, sparse_ledger) t ->
      let sparse_ledger' =
        Sparse_ledger.apply_transaction_exn sparse_ledger (t :> Transaction.t)
      in
      let span, proof = 
        time (fun () ->
          T.of_transaction
            (Sparse_ledger.merkle_root sparse_ledger)
            (Sparse_ledger.merkle_root sparse_ledger')
            t
            (unstage (Sparse_ledger.handler sparse_ledger)))
      in
      ((Time.Span.max span max_span, sparse_ledger'), proof))
  in
  let rec merge_all serial_time proofs =
    match proofs with
    | [ x ] -> serial_time
    | _ ->
      let layer_time, new_proofs =
        List.fold_map (pair_up proofs) ~init:Time.Span.zero ~f:(fun max_time (x, y) ->
          let (pair_time, proof) = time (fun () -> T.merge x y) in
          (Time.Span.max max_time pair_time, proof))
      in
      merge_all (Time.Span.(+) serial_time layer_time) new_proofs
  in
  let total_time = merge_all base_proof_time base_proofs in
  Printf.sprintf !"Total time was: %{Time.Span}" total_time

let check_snark sparse_ledger0 (transactions : Transaction.With_valid_signature.t list) =
  let module Sparse_ledger = Bundle.Sparse_ledger in
  let _ =
    List.fold transactions ~init:sparse_ledger0 ~f:(fun sparse_ledger t ->
      let sparse_ledger' =
        Sparse_ledger.apply_transaction_exn sparse_ledger (t :> Transaction.t)
      in
      let () = 
          Transaction_snark.check_transaction
            (Sparse_ledger.merkle_root sparse_ledger)
            (Sparse_ledger.merkle_root sparse_ledger')
            t
            (unstage (Sparse_ledger.handler sparse_ledger))
      in
      sparse_ledger')
  in
  "*** Snark checked successfully!!"

let run profiler num_transactions =
  let (ledger, transactions) = create_ledger_and_transactions num_transactions in
  let sparse_ledger =
    Bundle.Sparse_ledger.of_ledger_subset ledger
      (List.concat_map transactions ~f:(fun t ->
        let t = (t :> Transaction.t) in
        [ t.payload.receiver; Public_key.compress t.sender ]))
  in
  let message = profiler sparse_ledger transactions in
  Core.printf !"%s\n%!" message;
  exit 0

let main num_transactions_log2 () =
  Nanobit_base.Test_util.with_randomness 123456789 (fun () ->
    let num_transactions = `Count (Int.pow 2 num_transactions_log2) in
    let keys = Transaction_snark.Keys.create () in
    let module T = Transaction_snark.Make(struct let keys = keys end) in
    run (profile (module T)) num_transactions
  )

let dry _ () =
  Nanobit_base.Test_util.with_randomness 123456789 (fun () ->
    let num_transactions = `Two_from_same in
    run check_snark num_transactions
  )

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler" begin
    [%map_open
      let n = flag "k" ~doc:"log_2(number of transactions to snark)" (required int)
      and dry_run = flag "dry-run"
        ~doc:"Just check snark, don't keys or time anything" (required bool) in
      if dry_run then
        dry n
      else
        main n
    ]
  end
