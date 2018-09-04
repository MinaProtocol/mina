open Core
open Snark_params.Tick

include Sparse_ledger_lib.Sparse_ledger.Make (struct
            include Merkle_hash
          end)
          (Public_key.Compressed.Stable.V1)
          (struct
            include Account.Stable.V1

            let key {Account.public_key; _} = public_key

            let hash = Fn.compose Merkle_hash.of_digest Account.digest
          end)

let of_ledger_subset_exn ledger keys =
  List.fold keys
    ~f:(fun acc key ->
      add_path acc
        (Option.value_exn (Ledger.merkle_path ledger key))
        (Option.value_exn (Ledger.get_account ledger key)) )
    ~init:
      (of_hash ~depth:Ledger.max_depth
         (Merkle_hash.of_digest (Ledger.merkle_root ledger :> Pedersen.Digest.t)))

let apply_transaction_exn t ({sender; payload; _}: Transaction.t) =
  let {Transaction_payload.amount; fee; receiver; _} = payload in
  let sender_idx = find_index_exn t (Public_key.compress sender) in
  let receiver_idx = find_index_exn t receiver in
  let sender_account = get_exn t sender_idx in
  if not Insecure.fee_collection then
    failwith "Bundle.Sparse_ledger: Insecure.fee_collection" ;
  let open Currency in
  let t =
    set_exn t sender_idx
      { sender_account with
        nonce= Account.Nonce.succ sender_account.nonce
      ; balance=
          (let open Option in
          value_exn
            (let open Let_syntax in
            let%bind total = Amount.add_fee amount fee in
            Balance.sub_amount sender_account.balance total))
      ; receipt_chain_hash=
          Receipt.Chain_hash.cons payload sender_account.receipt_chain_hash }
  in
  let receiver_account = get_exn t receiver_idx in
  set_exn t receiver_idx
    { receiver_account with
      balance=
        Option.value_exn (Balance.add_amount receiver_account.balance amount)
    }

let apply_fee_transfer_exn =
  let apply_single t ((pk, fee): Fee_transfer.single) =
    let index = find_index_exn t pk in
    let account = get_exn t index in
    let open Currency in
    set_exn t index
      { account with
        balance=
          Option.value_exn
            (Balance.add_amount account.balance (Amount.of_fee fee)) }
  in
  fun t transfer ->
    List.fold (Fee_transfer.to_list transfer) ~f:apply_single ~init:t

let apply_super_transaction_exn t transition =
  match transition with
  | Super_transaction.Fee_transfer tr -> apply_fee_transfer_exn t tr
  | Transaction tr -> apply_transaction_exn t (tr :> Transaction.t)

let merkle_root t = Ledger_hash.of_hash (merkle_root t :> Pedersen.Digest.t)

let handler t =
  let ledger = ref t in
  let path_exn idx =
    List.map (path_exn !ledger idx) ~f:(function `Left h -> h | `Right h -> h)
  in
  stage (fun (With {request; respond}) ->
      match request with
      | Ledger_hash.Get_element idx ->
          let elt = get_exn !ledger idx in
          let path = (path_exn idx :> Pedersen.Digest.t list) in
          respond (Provide (elt, path))
      | Ledger_hash.Get_path idx ->
          let path = (path_exn idx :> Pedersen.Digest.t list) in
          respond (Provide path)
      | Ledger_hash.Set (idx, account) ->
          ledger := set_exn !ledger idx account ;
          respond (Provide ())
      | Ledger_hash.Find_index pk ->
          let index = find_index_exn !ledger pk in
          respond (Provide index)
      | _ -> unhandled )
