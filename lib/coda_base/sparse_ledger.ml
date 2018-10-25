open Core
open Snark_params.Tick
open Coda_numbers

include Sparse_ledger_lib.Sparse_ledger.Make (struct
            include Merkle_hash
          end)
          (Signature_lib.Public_key.Compressed.Stable.V1)
          (struct
            include Account.Stable.V1

            let hash = Fn.compose Merkle_hash.of_digest Account.digest
          end)

let conv_path =
  List.map ~f:(function
    | Ledger.Path.Direction.Left, x -> `Left x
    | Right, x -> `Right x )

let ledger_merkle_path ledger loc = conv_path (Ledger.merkle_path ledger loc)

let of_ledger_subset_exn (ledger: Ledger.t) keys =
  let new_keys, sparse =
    List.fold keys
      ~f:(fun (new_keys, sl) key ->
        match Ledger.location_of_key ledger key with
        | Some loc ->
            ( new_keys
            , add_path sl
                (ledger_merkle_path ledger loc)
                key
                (Ledger.get ledger loc |> Option.value_exn) )
        | None ->
            let path, acct = Ledger.create_empty ledger key in
            (key :: new_keys, add_path sl (conv_path path) key acct) )
      ~init:
        ( []
        , of_hash ~depth:Ledger.depth
            (Merkle_hash.of_digest
               (Ledger.merkle_root ledger :> Pedersen.Digest.t)) )
  in
  Ledger.remove_accounts_exn ledger new_keys ;
  Debug_assert.debug_assert (fun () ->
      [%test_eq : Ledger.Root_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sparse :> Pedersen.Digest.t) |> Ledger.Root_hash.of_hash)
  ) ;
  sparse

let%test_unit "of_ledger_subset_exn with keys that don't exist works" =
  let keygen () =
    let open Signature_lib in
    let privkey = Private_key.create () in
    (privkey, Public_key.of_private_key_exn privkey |> Public_key.compress)
  in
  let ledger = Ledger.create () in
  let _, pub1 = keygen () in
  let _, pub2 = keygen () in
  let sl = of_ledger_subset_exn ledger [pub1; pub2] in
  [%test_eq : Ledger_hash.t]
    (Ledger.merkle_root ledger)
    ((merkle_root sl :> Pedersen.Digest.t) |> Ledger_hash.of_hash)

let apply_payment_exn t ({sender; payload; signature= _}: Payment.t) =
  let {Payment_payload.amount; fee; receiver; nonce} = payload in
  let sender_idx =
    find_index_exn t (Signature_lib.Public_key.compress sender)
  in
  let receiver_idx = find_index_exn t receiver in
  let sender_account = get_exn t sender_idx in
  assert (Account_nonce.equal (Account.nonce sender_account) nonce) ;
  if not Insecure.fee_collection then
    failwith "Bundle.Sparse_ledger: Insecure.fee_collection" ;
  let open Currency in
  let t =
    set_exn t sender_idx
      (Account.create
         ~public_key:(Account.public_key sender_account)
         ~nonce:(Account_nonce.succ (Account.nonce sender_account))
         ~balance:
           (Option.value_exn
              (Option.bind
                 (Amount.add_fee amount fee)
                 ~f:(Balance.sub_amount (Account.balance sender_account))))
         ~receipt_chain_hash:
           (Receipt_chain_hash.cons payload
              (Account.receipt_chain_hash sender_account)))
  in
  let receiver_account = get_exn t receiver_idx in
  set_exn t receiver_idx
    (Account.create ~public_key:receiver
       ~nonce:(Account.nonce receiver_account)
       ~balance:
         (Option.value_exn
            (Balance.add_amount (Account.balance receiver_account) amount))
       ~receipt_chain_hash:(Account.receipt_chain_hash receiver_account))

let apply_fee_transfer_exn =
  let apply_single t ((pk, fee): Fee_transfer.single) =
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
    List.fold (Fee_transfer.to_single_list transfer) ~f:apply_single ~init:t

let apply_coinbase_exn t ({proposer; fee_transfer; amount}: Coinbase.t) =
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
    | None -> (amount, t)
    | Some (receiver, fee) ->
        let fee = Amount.of_fee fee in
        let reward = Amount.sub amount fee |> Option.value_exn in
        (reward, add_to_balance t receiver fee)
  in
  add_to_balance t proposer proposer_reward

let apply_transaction_exn t transition =
  match transition with
  | Transaction.Fee_transfer tr -> apply_fee_transfer_exn t tr
  | Valid_payment tr -> apply_payment_exn t (tr :> Payment.t)
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
          let i = Account.Index.to_int idx in
          let elt = get_exn !ledger i in
          let path = (path_exn i :> Pedersen.Digest.t list) in
          respond (Provide (elt, path))
      | Ledger_hash.Get_path idx ->
          let path =
            (path_exn (Account.Index.to_int idx) :> Pedersen.Digest.t list)
          in
          respond (Provide path)
      | Ledger_hash.Set (idx, account) ->
          ledger := set_exn !ledger (Account.Index.to_int idx) account ;
          respond (Provide ())
      | Ledger_hash.Find_index pk ->
          let index = find_index_exn !ledger pk in
          respond (Provide (Account.Index.of_int index))
      | _ -> unhandled )
