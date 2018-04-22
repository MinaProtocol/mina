open Core
open Snark_params
open Currency

include Merkle_ledger.Ledger.Make
    (struct
      type account = Account.t [@@deriving sexp, bin_io]
      type hash = Tick.Pedersen.Digest.t [@@deriving sexp, hash, compare, bin_io]

      let empty_hash =
        Tick.Pedersen.hash_bigstring (Bigstring.of_string "nothing up my sleeve")

      let merge t1 t2 =
        let open Tick.Pedersen in
        hash_fold params (fun ~init ~f ->
          let init = Digest.Bits.fold t1 ~init ~f in
          Digest.Bits.fold t2 ~init ~f)

      let hash_account account =
        Tick.Pedersen.hash_fold Tick.Pedersen.params
          (Account.fold_bits account)
    end)
    (Public_key.Compressed)
    (struct let depth = ledger_depth end)

let merkle_root t = Ledger_hash.of_hash (merkle_root t)

let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

let get' ledger tag key = error_opt (sprintf "%s not found" tag) (get ledger key)

let add_amount balance amount = error_opt "overflow" (Balance.add_amount balance amount)
let sub_amount balance amount = error_opt "insufficient funds" (Balance.sub_amount balance amount)

let apply_transaction_unchecked ledger (transaction : Transaction.t) =
  let sender = Public_key.compress transaction.sender in
  let { Transaction.Payload.fee=_; amount; receiver } = transaction.payload in
  let open Or_error.Let_syntax in
  let%bind sender_account = get' ledger "sender" sender
  and receiver_account = get' ledger "receiver" receiver
  in
  let%map sender_balance' = sub_amount sender_account.balance amount
  and receiver_balance' = add_amount receiver_account.balance amount
  in
  update ledger sender { sender_account with balance = sender_balance' };
  update ledger receiver { receiver_account with balance = receiver_balance' }

let apply_transaction ledger transaction =
  if Transaction.check_signature transaction
  then apply_transaction_unchecked ledger transaction
  else error "bad signature"

let undo_transaction ledger (transaction : Transaction.t) =
  let open Or_error.Let_syntax in
  let sender = Public_key.compress transaction.sender in
  let { Transaction.Payload.fee=_; amount; receiver } = transaction.payload in
  let%bind sender_account = get' ledger "sender" sender
  and receiver_account = get' ledger "receiver" receiver
  in
  let%map sender_balance' = add_amount sender_account.balance amount
  and receiver_balance' = sub_amount receiver_account.balance amount
  in
  update ledger sender { sender_account with balance = sender_balance' };
  update ledger receiver { receiver_account with balance = receiver_balance' }

let merkle_root_after_transaction_exn ledger transaction =
  Or_error.ok_exn (apply_transaction ledger transaction);
  let root = merkle_root ledger in
  Or_error.ok_exn (undo_transaction ledger transaction);
  root
