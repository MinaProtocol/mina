open Core
open Signature_lib
open Coda_base
open Snark_params

(* We're just profiling, so okay to monkey-patch here *)
module Sparse_ledger = struct
  include Sparse_ledger

  let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
end

let create_ledger_and_transactions num_transitions =
  let open Tick in
  let num_accounts = 4 in
  let ledger = Ledger.create () in
  let keys =
    Array.init num_accounts ~f:(fun _ -> Signature_lib.Keypair.create ())
  in
  Array.iter keys ~f:(fun k ->
      let public_key = Public_key.compress k.public_key in
      Ledger.create_new_account_exn ledger public_key
        { public_key
        ; balance= Currency.Balance.of_int 10_000
        ; receipt_chain_hash= Receipt.Chain_hash.empty
        ; nonce= Account.Nonce.zero } ) ;
  let txn from_kp (to_kp : Signature_lib.Keypair.t) amount fee nonce =
    let payload : Transaction.Payload.t =
      {receiver= Public_key.compress to_kp.public_key; fee; amount; nonce}
    in
    Transaction.sign from_kp payload
  in
  let nonces =
    Public_key.Compressed.Table.of_alist_exn
      (List.map (Array.to_list keys) ~f:(fun k ->
           (Public_key.compress k.public_key, Account.Nonce.zero) ))
  in
  let random_transaction () : Transaction.With_valid_signature.t =
    let sender_idx = Random.int num_accounts in
    let sender = keys.(sender_idx) in
    let receiver = keys.(Random.int num_accounts) in
    let sender_pk = Public_key.compress sender.public_key in
    let nonce = Hashtbl.find_exn nonces sender_pk in
    Hashtbl.change nonces sender_pk ~f:(Option.map ~f:Account.Nonce.succ) ;
    let fee = Currency.Fee.of_int (1 + Random.int 100) in
    let amount = Currency.Amount.of_int (1 + Random.int 100) in
    txn sender receiver amount fee nonce
  in
  match num_transitions with
  | `Count n ->
      let num_transactions = n - 2 in
      let transactions =
        List.rev (List.init num_transactions (fun _ -> random_transaction ()))
      in
      let fee_transfer =
        let open Currency.Fee in
        let total_fee =
          List.fold transactions ~init:zero ~f:(fun acc t ->
              Option.value_exn (add acc (t :> Transaction.t).payload.fee) )
        in
        Fee_transfer.One (Public_key.compress keys.(0).public_key, total_fee)
      in
      let coinbase =
        Coinbase.create ~amount:Protocols.Coda_praos.coinbase_amount
          ~proposer:(Public_key.compress keys.(0).public_key)
          ~fee_transfer:None
        |> Or_error.ok_exn
      in
      let transitions =
        List.map transactions ~f:(fun t ->
            Transaction_snark.Transition.Transaction t )
        @ [Coinbase coinbase; Fee_transfer fee_transfer]
      in
      (ledger, transitions)
  | `Two_from_same ->
      let a =
        txn keys.(0) keys.(1)
          (Currency.Amount.of_int 10)
          Currency.Fee.zero Account.Nonce.zero
      in
      let b =
        txn keys.(0) keys.(1)
          (Currency.Amount.of_int 10)
          Currency.Fee.zero
          (Account.Nonce.succ Account.Nonce.zero)
      in
      (ledger, [Transaction a; Transaction b])

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
let profile (module T : Transaction_snark.S) sparse_ledger0
    (transitions : Transaction_snark.Transition.t list) =
  let (base_proof_time, _), base_proofs =
    List.fold_map transitions ~init:(Time.Span.zero, sparse_ledger0)
      ~f:(fun (max_span, sparse_ledger) t ->
        let sparse_ledger' =
          Sparse_ledger.apply_super_transaction_exn sparse_ledger t
        in
        let span, proof =
          time (fun () ->
              T.of_transition ~sok_digest:Sok_message.Digest.default
                ~source:(Sparse_ledger.merkle_root sparse_ledger)
                ~target:(Sparse_ledger.merkle_root sparse_ledger')
                t
                (unstage (Sparse_ledger.handler sparse_ledger)) )
        in
        ((Time.Span.max span max_span, sparse_ledger'), proof) )
  in
  let rec merge_all serial_time proofs =
    match proofs with
    | [x] -> serial_time
    | _ ->
        let layer_time, new_proofs =
          List.fold_map (pair_up proofs) ~init:Time.Span.zero
            ~f:(fun max_time (x, y) ->
              let pair_time, proof =
                time (fun () ->
                    T.merge ~sok_digest:Sok_message.Digest.default x y
                    |> Or_error.ok_exn )
              in
              (Time.Span.max max_time pair_time, proof) )
        in
        merge_all (Time.Span.( + ) serial_time layer_time) new_proofs
  in
  let total_time = merge_all base_proof_time base_proofs in
  Printf.sprintf !"Total time was: %{Time.Span}" total_time

let check_base_snarks sparse_ledger0
    (transitions : Transaction_snark.Transition.t list) =
  let _ =
    let sok_message =
      Sok_message.create ~fee:Currency.Fee.zero
        ~prover:
          Public_key.(compress (of_private_key_exn (Private_key.create ())))
    in
    List.fold transitions ~init:sparse_ledger0 ~f:(fun sparse_ledger t ->
        let sparse_ledger' =
          Sparse_ledger.apply_super_transaction_exn sparse_ledger t
        in
        let () =
          Transaction_snark.check_transition ~sok_message
            ~source:(Sparse_ledger.merkle_root sparse_ledger)
            ~target:(Sparse_ledger.merkle_root sparse_ledger')
            t
            (unstage (Sparse_ledger.handler sparse_ledger))
        in
        sparse_ledger' )
  in
  "Base constraint system satisfied"

let run profiler num_transactions =
  let ledger, transitions = create_ledger_and_transactions num_transactions in
  let sparse_ledger =
    Coda_base.Sparse_ledger.of_ledger_subset_exn ledger
      (List.concat_map transitions ~f:(fun t ->
           match t with
           | Fee_transfer t ->
               List.map (Fee_transfer.to_list t) ~f:(fun (pk, _) -> pk)
           | Transaction t ->
               let t = (t :> Transaction.t) in
               [t.payload.receiver; Public_key.compress t.sender]
           | Coinbase {proposer; fee_transfer} ->
               proposer :: Option.to_list (Option.map fee_transfer ~f:fst) ))
  in
  let message = profiler sparse_ledger transitions in
  Core.printf !"%s\n%!" message ;
  exit 0

let main num_transactions () =
  Test_util.with_randomness 123456789 (fun () ->
      let keys = Transaction_snark.Keys.create () in
      let module T = Transaction_snark.Make (struct
        let keys = keys
      end) in
      run (profile (module T)) num_transactions )

let dry num_transactions () =
  Test_util.with_randomness 123456789 (fun () ->
      run check_base_snarks num_transactions )

let command =
  let open Command.Let_syntax in
  Command.basic ~summary:"transaction snark profiler"
    (let%map_open n =
       flag "k"
         ~doc:
           "log_2(number of transactions to snark) or none for the mocked ones"
         (optional int)
     and check_only =
       flag "check-only"
         ~doc:"Just check base snarks, don't keys or time anything" no_arg
     in
     let num_transactions =
       Option.map n ~f:(fun n -> `Count (Int.pow 2 n))
       |> Option.value ~default:`Two_from_same
     in
     if check_only then dry num_transactions else main num_transactions)
