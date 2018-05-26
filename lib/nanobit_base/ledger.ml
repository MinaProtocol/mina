open Core
open Snark_params
open Currency

include Merkle_ledger.Ledger.Make
    (Account)
    (struct
      type hash = Tick.Pedersen.Digest.t
      [@@deriving sexp, hash, compare, bin_io]

      let empty_hash =
        Tick.Pedersen.hash_bigstring (Bigstring.of_string "nothing up my sleeve")

      let merge = Merkle_hash.merge

      let hash_account = Account.digest
    end)
    (Public_key.Compressed)
    (struct let depth = ledger_depth end)

let merkle_root t = Ledger_hash.of_hash (merkle_root t)

let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

let get' ledger tag key = error_opt (sprintf "%s not found" tag) (get ledger key)

let add_amount balance amount = error_opt "overflow" (Balance.add_amount balance amount)
let sub_amount balance amount = error_opt "insufficient funds" (Balance.sub_amount balance amount)
let add_fee amount fee = error_opt "add_fee: overflow" (Amount.add_fee amount fee)

let validate_nonces txn_nonce account_nonce =
  if Account.Nonce.equal account_nonce txn_nonce then
    Or_error.return ()
  else
    Or_error.errorf !"Nonce in account %{sexp: Account.Nonce.t} different from nonce in transaction %{sexp: Account.Nonce.t}" account_nonce txn_nonce

let apply_transaction_unchecked ledger ({ payload; sender } : Transaction.t) =
  let sender = Public_key.compress sender in
  let { Transaction.Payload.fee; amount; receiver; nonce } = payload in
  let open Or_error.Let_syntax in
  let%bind sender_account = get' ledger "sender" sender in
  let%bind () = validate_nonces nonce sender_account.nonce in
  let%bind sender_balance' =
    let%bind amount_and_fee = add_fee amount fee in
    sub_amount sender_account.balance amount_and_fee
  in
  if Public_key.Compressed.equal sender receiver
  then return ()
  else
    let%bind receiver_account = get' ledger "receiver" receiver in
    let%map receiver_balance' = add_amount receiver_account.balance amount in
    set ledger sender { sender_account with balance = sender_balance' ; nonce = Account.Nonce.succ nonce };
    set ledger receiver { receiver_account with balance = receiver_balance' }

let apply_transaction ledger (transaction : Transaction.With_valid_signature.t) =
  apply_transaction_unchecked ledger (transaction :> Transaction.t)

let undo_transaction ledger ({ payload; sender } : Transaction.t) =
  let sender = Public_key.compress sender in
  let { Transaction.Payload.fee; amount; receiver; nonce } = payload in
  let open Or_error.Let_syntax in
  let%bind sender_account = get' ledger "sender" sender in
  let%bind sender_balance' =
    let%bind amount_and_fee = add_fee amount fee in
    add_amount sender_account.balance amount_and_fee
  in
  let%bind () = validate_nonces (Account.Nonce.succ nonce) sender_account.nonce in
  if Public_key.Compressed.equal sender receiver
  then return ()
  else
    let%bind receiver_account = get' ledger "receiver" receiver in
    let%map receiver_balance' = sub_amount receiver_account.balance amount in
    set ledger sender { sender_account with balance = sender_balance' ; nonce };
    set ledger receiver { receiver_account with balance = receiver_balance' }

let merkle_root_after_transaction_exn ledger transaction =
  Or_error.ok_exn (apply_transaction ledger transaction);
  let root = merkle_root ledger in
  Or_error.ok_exn (undo_transaction ledger (transaction :> Transaction.t));
  root

let merkle_root_after_transactions t ts =
  let ts_rev =
    List.rev_map ts ~f:(fun txn ->
      ignore (apply_transaction t txn);
      txn);
  in
  let root = merkle_root t in
  List.iter ts_rev ~f:(fun txn ->
    ignore (undo_transaction t (txn :> Transaction.t)));
  root

let process_fee_transfer t (transfer : Fee_transfer.t) ~modify_balance =
  let open Or_error.Let_syntax in
  match transfer with
  | One (pk, fee) ->
    let%map a = get' t "One-pk" pk in
    set t pk { a with balance = modify_balance a.balance fee }
  | Two ((pk1, fee1), (pk2, fee2)) ->
    let%map a1 = get' t "Two-pk1" pk1
    and a2 = get' t "Two-pk2" pk2
    in
    set t pk1 { a1 with balance = modify_balance a1.balance fee1 };
    set t pk2 { a2 with balance = modify_balance a2.balance fee2 }

let apply_fee_transfer t transfer =
  process_fee_transfer t transfer
    ~modify_balance:(fun b f -> Option.value_exn (Balance.add_amount b (Amount.of_fee f)))

let undo_fee_transfer t transfer =
  process_fee_transfer t transfer
    ~modify_balance:(fun b f -> Option.value_exn (Balance.sub_amount b (Amount.of_fee f)))
