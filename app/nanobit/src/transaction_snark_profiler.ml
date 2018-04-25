open Core
open Nanobit_base
open Snark_params

let create_ledger_and_transactions num_transactions =
  let open Tick in
  let num_accounts = 4 in
  let ledger = Ledger.create () in
  let keys = Array.init num_accounts ~f:(fun _ -> Signature_keypair.create ()) in
  Array.iter keys ~f:(fun k ->
    let public_key = Public_key.compress k.public_key in
    Ledger.update ledger public_key
      { public_key; balance = Currency.Balance.of_int 10_000 });
  let random_transaction () : Transaction.t =
    let sender = keys.(Random.int num_accounts) in
    let receiver = keys.(Random.int num_accounts) in
    let payload : Transaction.Payload.t =
      { receiver = Public_key.compress receiver.public_key
      ; fee = Currency.Fee.zero
      ; amount = Currency.Amount.of_int (1 + Random.int 100)
      }
    in
    Transaction.sign sender payload
  in
  (ledger, List.init num_transactions (fun _ -> random_transaction ()))

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
let profile (module T : Transaction_snark.S) sparse_ledger0 (transactions : Transaction.t list) =
  let module Sparse_ledger = Bundle.Sparse_ledger in
  let (base_proof_time, _), base_proofs =
    List.fold_map transactions ~init:(Time.Span.zero, sparse_ledger0) ~f:(fun (max_span, sparse_ledger) t ->
      let sparse_ledger' =
        Sparse_ledger.apply_transaction_exn sparse_ledger t
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
  merge_all base_proof_time base_proofs

let main num_transactions_log2 () =
  Nanobit_base.Test_util.with_randomness 123456789 (fun () ->
    let num_transactions = Int.pow 2 num_transactions_log2 in
    let keys = Transaction_snark.Keys.create () in
    let module T = Transaction_snark.Make(struct let keys = keys end) in
    let (ledger, transactions) = create_ledger_and_transactions num_transactions in
    let sparse_ledger =
      Bundle.Sparse_ledger.of_ledger_subset ledger
        (List.concat_map transactions ~f:(fun t ->
          [ t.payload.receiver; Public_key.compress t.sender ]))
    in
    let total_time = profile (module T) sparse_ledger transactions in
    Core.printf !"Total time was: %{Time.Span}\n%!" total_time
  )

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler" begin
    let%map_open n = flag "k" ~doc:"log_2(number of transactions to snark)" (required int) in
    main n
  end
