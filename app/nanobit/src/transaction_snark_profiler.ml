open Core
open Nanobit_base

let create_ledger_and_transactions num_transactions =
  let open Snark_params.Tick in
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

let profile (module T : Transaction_snark.S) ledger transactions =
  let handler = Transaction_snark.handle_with_ledger ledger in
  let base_proof_time, base_proofs =
    time (fun () ->
      List.map transactions ~f:(fun t ->
        T.of_transaction
          (Ledger.merkle_root ledger)
          (Ledger.root_after_transaction_exn ledger t)
          t
          handler))
  in
  let rec merge_all serial_time proofs =
    match proofs with
    | [ x ] -> serial_time
    | _ ->
      let layer_time, new_proofs =
        time (fun () ->
          List.map (pair_up proofs) ~f:(fun (x, y) -> T.merge x y))
      in
      merge_all (Time.Span.(+) serial_time layer_time) new_proofs
  in
  merge_all base_proof_time base_proofs

let main num_transactions_log2 () =
  Nanobit_base.Test_util.with_randomness 123456789 (fun () ->
    let num_transactions = Int.pow 2 num_transactions_log2 in
    let keys = (let module Keys = Keys.Make() in Keys.transaction_snark_keys)
    in
    let module T = Transaction_snark.Make(struct let keys = keys end) in
    let (ledger, transactions) = create_ledger_and_transactions num_transactions in
    let total_time = profile (module T) ledger transactions in
    printf !"Total time was: %{Time.Span}" total_time
  )
;;

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler" begin
    let%map_open n = flag "k" ~doc:"log_2(number of transactions to snark)" (required int) in
    main n
  end

