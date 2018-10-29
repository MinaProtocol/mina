open Core
open Import
open Snark_params.Tick

include Sparse_ledger_lib.Sparse_ledger.Make (struct
            include Merkle_hash
          end)
          (Public_key.Compressed.Stable.V1)
          (struct
            include Account.Stable.V1

            let hash = Fn.compose Merkle_hash.of_digest Account.digest
          end)

let of_ledger_subset_exn (ledger : Ledger.t) keys =
  let new_keys, sparse =
    List.fold keys
      ~f:(fun (new_keys, sl) key ->
        match Ledger.location_of_key ledger key with
        | Some loc ->
            ( new_keys
            , add_path sl
                (Ledger.merkle_path ledger loc)
                key
                (Ledger.get ledger loc |> Option.value_exn) )
        | None ->
            let path, acct = Ledger.create_empty ledger key in
            (key :: new_keys, add_path sl path key acct) )
      ~init:
        ( []
        , of_hash ~depth:Ledger.depth
            (Merkle_hash.of_digest
               (Ledger.merkle_root ledger :> Pedersen.Digest.t)) )
  in
  Ledger.remove_accounts_exn ledger new_keys ;
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sparse :> Pedersen.Digest.t) |> Ledger_hash.of_hash) ) ;
  sparse

let%test_unit "of_ledger_subset_exn with keys that don't exist works" =
  let keygen () =
    let privkey = Private_key.create () in
    (privkey, Public_key.of_private_key_exn privkey |> Public_key.compress)
  in
  let ledger = Ledger.create () in
  let _, pub1 = keygen () in
  let _, pub2 = keygen () in
  let sl = of_ledger_subset_exn ledger [pub1; pub2] in
  [%test_eq: Ledger_hash.t]
    (Ledger.merkle_root ledger)
    ((merkle_root sl :> Pedersen.Digest.t) |> Ledger_hash.of_hash)

let apply_transaction_exn t ({sender; payload; signature= _} : Transaction.t) =
  let {Transaction_payload.amount; fee; receiver; nonce} = payload in
  let sender_idx = find_index_exn t (Public_key.compress sender) in
  let receiver_idx = find_index_exn t receiver in
  let sender_account = get_exn t sender_idx in
  assert (Account.Nonce.equal sender_account.nonce nonce) ;
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
      public_key= receiver
    ; balance=
        Option.value_exn (Balance.add_amount receiver_account.balance amount)
    }

let apply_fee_transfer_exn =
  let apply_single t ((pk, fee) : Fee_transfer.single) =
    let index = find_index_exn t pk in
    let account = get_exn t index in
    let open Currency in
    set_exn t index
      { account with
        public_key= pk (* explicitly set because receipient could be new *)
      ; balance=
          Option.value_exn
            (Balance.add_amount account.balance (Amount.of_fee fee)) }
  in
  fun t transfer ->
    List.fold (Fee_transfer.to_list transfer) ~f:apply_single ~init:t

let apply_coinbase_exn t ({proposer; fee_transfer} : Coinbase.t) =
  let open Currency in
  let add_to_balance t pk amount =
    let idx = find_index_exn t pk in
    let a = get_exn t idx in
    set_exn t idx
      { a with
        public_key= pk
      ; (* set as above *)
        balance= Option.value_exn (Balance.add_amount a.balance amount) }
  in
  let proposer_reward, t =
    match fee_transfer with
    | None -> (Protocols.Coda_praos.coinbase_amount, t)
    | Some (receiver, fee) ->
        let fee = Amount.of_fee fee in
        let reward =
          Amount.sub Protocols.Coda_praos.coinbase_amount fee
          |> Option.value_exn
        in
        (reward, add_to_balance t receiver fee)
  in
  add_to_balance t proposer proposer_reward

let apply_super_transaction_exn t transition =
  match transition with
  | Super_transaction.Fee_transfer tr -> apply_fee_transfer_exn t tr
  | Transaction tr -> apply_transaction_exn t (tr :> Transaction.t)
  | Coinbase c -> apply_coinbase_exn t c

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
