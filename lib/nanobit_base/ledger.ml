open Core
open Snark_params
open Currency

module My_Key = struct

  include Public_key.Compressed

  let to_string key =
    let bin_size = Public_key.Compressed.bin_size_t key in
    let buf = Bigstring.create bin_size in
    ignore (Public_key.Compressed.bin_write_t buf ~pos:0 key) ;
    Bigstring.to_string buf
end

module Account = struct
  include Account

  let set_balance t new_balance = {t with balance= new_balance}

  let public_key (t: t) = public_key t
end

include Merkle_ledger.Database.Make (My_Key) (Account)
          (struct
            type t = Merkle_hash.t [@@deriving sexp, hash, compare, bin_io]

            let merge = Merkle_hash.merge

            let empty = Merkle_hash.empty_hash

            let hash_account = Fn.compose Merkle_hash.of_digest Account.digest
          end)
          (struct
            let depth = ledger_depth
          end)
          (Merkle_ledger.Test_stubs.In_memory_kvdb)
          (Merkle_ledger.Test_stubs.In_memory_sdb)

let merkle_path_at_index_exn t index =
  merkle_path_at_addr t (Addr.of_index_exn index)

let get_at_index_exn t index = 
  get_account_from_key t (of_index index) |> Option.value_exn

let set_at_index_exn t index account = 
  update_account t (of_index index) account

let index_of_key_exn t public_key =
  public_key_to_index t public_key |> 
  Option.value_exn |>
  to_index

let merkle_path_at_addr_exn = merkle_path_at_addr

let depth = ledger_depth

let length = num_accounts

let copy t = t

let t_of_sexp = opaque_of_sexp

let sexp_of_t = sexp_of_opaque

let create () = create ~key_value_db_dir:"" ~stack_db_file:""

let set t pk account = update_account t (public_key_to_index t pk |> Option.value_exn) account

let merkle_root t =
  Ledger_hash.of_hash (merkle_root t :> Tick.Pedersen.Digest.t)

let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

let get' ledger tag key =
  error_opt (sprintf "%s not found" tag) (get_account ledger key)

let set' ledger account : unit Or_error.t =
  set_account ledger account |>
  Result.map_error ~f:(fun error -> Error.create "" error [%sexp_of: error])

let add_amount balance amount =
  error_opt "overflow" (Balance.add_amount balance amount)

let sub_amount balance amount =
  error_opt "insufficient funds" (Balance.sub_amount balance amount)

let add_fee amount fee =
  error_opt "add_fee: overflow" (Amount.add_fee amount fee)

let validate_nonces txn_nonce account_nonce =
  if Account.Nonce.equal account_nonce txn_nonce then Or_error.return ()
  else
    Or_error.errorf
      !"Nonce in account %{sexp: Account.Nonce.t} different from nonce in \
        transaction %{sexp: Account.Nonce.t}"
      account_nonce txn_nonce

module Undo = struct
  type transaction =
    { transaction: Transaction.t
    ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
  [@@deriving sexp]

  type t = Transaction of transaction | Fee_transfer of Fee_transfer.t
  [@@deriving sexp]
end

(* someday: It would probably be better if we didn't modify the receipt chain hash
   in the case that the sender is equal to the receiver, but it complicates the SNARK, so
   we don't for now. *)
let apply_transaction_unchecked ledger
    ({payload; sender; _} as transaction: Transaction.t) =
  let sender = Public_key.compress sender in
  
  let {Transaction.Payload.fee; amount; receiver; nonce} = payload in
  let open Or_error.Let_syntax in
  let%bind sender_account = get' ledger "sender" sender in
  let%bind () = validate_nonces nonce sender_account.nonce in
  let%bind sender_balance' =
    let%bind amount_and_fee = add_fee amount fee in
    sub_amount sender_account.balance amount_and_fee
  in
  let sender_account_without_balance_modified =
    { sender_account with
      nonce= Account.Nonce.succ sender_account.nonce
    ; receipt_chain_hash=
        Receipt.Chain_hash.cons payload sender_account.receipt_chain_hash }
  in
  let undo =
    { Undo.transaction
    ; previous_receipt_chain_hash= sender_account.receipt_chain_hash }
  in
  if Public_key.Compressed.equal sender receiver then (
    let%bind () = set' ledger sender_account_without_balance_modified in
    return undo )
  else
    let%bind receiver_account = get' ledger "receiver" receiver in
    let%bind receiver_balance' = add_amount receiver_account.balance amount in
    let%bind () = set' ledger
      {sender_account_without_balance_modified with balance= sender_balance'} in
    let%map () = set' ledger {receiver_account with balance= receiver_balance'} in
    undo

let apply_transaction ledger (transaction: Transaction.With_valid_signature.t) =
  apply_transaction_unchecked ledger (transaction :> Transaction.t)

let process_fee_transfer t (transfer: Fee_transfer.t) ~modify_balance =
  let open Or_error.Let_syntax in
  match transfer with
  | One (pk, fee) ->
      let%bind a = get' t "One-pk" pk in
      set' t {a with balance= modify_balance a.balance fee}
  | Two ((pk1, fee1), (pk2, fee2)) ->
      let%bind a1 = get' t "Two-pk1" pk1 and a2 = get' t "Two-pk2" pk2 in
      let%bind () = set' t {a1 with balance= modify_balance a1.balance fee1} in
      set' t {a2 with balance= modify_balance a2.balance fee2}

let apply_fee_transfer t transfer =
  process_fee_transfer t transfer ~modify_balance:(fun b f ->
      Option.value_exn (Balance.add_amount b (Amount.of_fee f)) )

let undo_fee_transfer t transfer =
  process_fee_transfer t transfer ~modify_balance:(fun b f ->
      Option.value_exn (Balance.sub_amount b (Amount.of_fee f)) )

let undo_transaction ledger
    {Undo.transaction= {payload; sender; _}; previous_receipt_chain_hash} =
  let sender = Public_key.compress sender in
  let {Transaction.Payload.fee; amount; receiver; nonce} = payload in
  let open Or_error.Let_syntax in
  let%bind sender_account = get' ledger "sender" sender in
  let%bind sender_balance' =
    let%bind amount_and_fee = add_fee amount fee in
    add_amount sender_account.balance amount_and_fee
  in
  let%bind () =
    validate_nonces (Account.Nonce.succ nonce) sender_account.nonce
  in
  let sender_account_without_balance_modified =
    {sender_account with nonce; receipt_chain_hash= previous_receipt_chain_hash}
  in
  if Public_key.Compressed.equal sender receiver then (
    set' ledger sender_account_without_balance_modified
    )
  else
    let%bind receiver_account = get' ledger "receiver" receiver in
    let%bind receiver_balance' = sub_amount receiver_account.balance amount in
    let%bind () = set' ledger 
      {sender_account_without_balance_modified with balance= sender_balance'} in
    set' ledger {receiver_account with balance= receiver_balance'}

let undo : t -> Undo.t -> unit Or_error.t =
 fun ledger undo ->
  match undo with
  | Fee_transfer t -> undo_fee_transfer ledger t
  | Transaction u -> undo_transaction ledger u

let apply_super_transaction ledger (t: Super_transaction.t) =
  match t with
  | Transaction txn ->
      Or_error.map (apply_transaction ledger txn) ~f:(fun u ->
          Undo.Transaction u )
  | Fee_transfer t ->
      Or_error.map (apply_fee_transfer ledger t) ~f:(fun () ->
          Undo.Fee_transfer t )

let merkle_root_after_transaction_exn ledger transaction =
  let undo = Or_error.ok_exn (apply_transaction ledger transaction) in
  let root = merkle_root ledger in
  Or_error.ok_exn (undo_transaction ledger undo) ;
  root

let merkle_root_after_transactions t ts =
  let undos_rev =
    List.rev_map ts ~f:(fun txn -> Or_error.ok_exn (apply_transaction t txn))
  in
  let root = merkle_root t in
  List.iter undos_rev ~f:(fun u -> Or_error.ok_exn (undo_transaction t u)) ;
  root
