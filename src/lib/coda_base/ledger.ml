open Core
open Snark_params
open Currency
open Signature_lib

module Make
    (Ledger : Merkle_ledger.Merkle_ledger_intf.S
              with type root_hash := Merkle_hash.t
               and type hash := Merkle_hash.t
               and type account := Account.t
               and type key := Public_key.Compressed.t) =
struct
  include Ledger

  let create_new_account_exn t pk account =
    let action, _ = get_or_create_account_exn t pk account in
    assert (action = `Added)

  let merkle_root t =
    Ledger_hash.of_hash (merkle_root t :> Tick.Pedersen.Digest.t)

  let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

  let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

  let get' ledger tag location =
    error_opt (sprintf "%s account not found" tag) (get ledger location)

  let location_of_key' ledger tag key =
    error_opt
      (sprintf "%s location not found" tag)
      (location_of_key ledger key)

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

  let get_or_create ledger key =
    let key, loc =
      match get_or_create_account_exn ledger key (Account.initialize key) with
      | `Existed, loc -> ([], loc)
      | `Added, loc -> ([key], loc)
    in
    (key, get ledger loc |> Option.value_exn, loc)

  let create_empty ledger k =
    let start_hash = merkle_root ledger in
    match get_or_create_account_exn ledger k Account.empty with
    | `Existed, _ -> failwith "create_empty for a key already present"
    | `Added, new_loc ->
        Debug_assert.debug_assert (fun () ->
            [%test_eq: Ledger_hash.t] start_hash (merkle_root ledger) ) ;
        (merkle_path ledger new_loc, Account.empty)

  module Undo = struct
    type transaction =
      { transaction: Transaction.t
      ; previous_empty_accounts: Public_key.Compressed.t list
      ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
    [@@deriving sexp, bin_io]

    type fee_transfer =
      { fee_transfer: Fee_transfer.t
      ; previous_empty_accounts: Public_key.Compressed.t list }
    [@@deriving sexp, bin_io]

    type coinbase =
      { coinbase: Coinbase.t
      ; previous_empty_accounts: Public_key.Compressed.t list }
    [@@deriving sexp, bin_io]

    type varying =
      | Transaction of transaction
      | Fee_transfer of fee_transfer
      | Coinbase of coinbase
    [@@deriving sexp, bin_io]

    type t = {previous_hash: Ledger_hash.t; varying: varying}
    [@@deriving sexp, bin_io]

    let super_transaction : t -> Super_transaction.t Or_error.t =
     fun {varying; _} ->
      let open Or_error.Let_syntax in
      match varying with
      | Transaction tr ->
          Option.value_map ~default:(Or_error.error_string "Bad signature")
            (Transaction.check tr.transaction) ~f:(fun x ->
              Ok (Super_transaction.Transaction x) )
      | Fee_transfer f -> Ok (Fee_transfer f.fee_transfer)
      | Coinbase c -> Ok (Coinbase c.coinbase)
  end

  (* someday: It would probably be better if we didn't modify the receipt chain hash
   in the case that the sender is equal to the receiver, but it complicates the SNARK, so
   we don't for now. *)
  let apply_transaction_unchecked ledger
      ({payload; sender; signature= _} as transaction : Transaction.t) =
    let sender = Public_key.compress sender in
    let {Transaction.Payload.fee; amount; receiver; nonce} = payload in
    let open Or_error.Let_syntax in
    let%bind sender_location = location_of_key' ledger "" sender in
    let%bind sender_account = get' ledger "sender" sender_location in
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
      ; previous_empty_accounts= []
      ; previous_receipt_chain_hash= sender_account.receipt_chain_hash }
    in
    if Public_key.Compressed.equal sender receiver then (
      ignore
      @@ set ledger sender_location sender_account_without_balance_modified ;
      return undo )
    else
      let previous_empty_accounts, receiver_account, receiver_location =
        get_or_create ledger receiver
      in
      let%map receiver_balance' = add_amount receiver_account.balance amount in
      set ledger sender_location
        {sender_account_without_balance_modified with balance= sender_balance'} ;
      set ledger receiver_location
        {receiver_account with balance= receiver_balance'} ;
      {undo with previous_empty_accounts}

  let apply_transaction ledger
      (transaction : Transaction.With_valid_signature.t) =
    apply_transaction_unchecked ledger (transaction :> Transaction.t)

  let process_fee_transfer t (transfer : Fee_transfer.t) ~modify_balance =
    let open Or_error.Let_syntax in
    match transfer with
    | One (pk, fee) ->
        let emptys, a, loc = get_or_create t pk in
        let%map balance = modify_balance a.balance fee in
        set t loc {a with balance} ;
        emptys
    | Two ((pk1, fee1), (pk2, fee2)) ->
        let emptys1, a1, l1 = get_or_create t pk1 in
        if Public_key.Compressed.equal pk1 pk2 then (
          let%bind fee = error_opt "overflow" (Fee.add fee1 fee2) in
          let%map balance = modify_balance a1.balance fee in
          set t l1 {a1 with balance} ;
          emptys1 )
        else
          let emptys2, a2, l2 = get_or_create t pk1 in
          let%bind balance1 = modify_balance a1.balance fee1 in
          let%map balance2 = modify_balance a2.balance fee2 in
          set t l1 {a1 with balance= balance1} ;
          set t l2 {a2 with balance= balance2} ;
          emptys1 @ emptys2

  let apply_fee_transfer t transfer =
    let open Or_error.Let_syntax in
    let%map previous_empty_accounts =
      process_fee_transfer t transfer ~modify_balance:(fun b f ->
          add_amount b (Amount.of_fee f) )
    in
    {Undo.fee_transfer= transfer; previous_empty_accounts}

  let undo_fee_transfer t
      ({previous_empty_accounts; fee_transfer} : Undo.fee_transfer) =
    let open Or_error.Let_syntax in
    let%map _ =
      process_fee_transfer t fee_transfer ~modify_balance:(fun b f ->
          sub_amount b (Amount.of_fee f) )
    in
    remove_accounts_exn t previous_empty_accounts

  (* TODO: Better system needed for making atomic changes. Could use a monad. *)
  let apply_coinbase t ({proposer; fee_transfer; _} as cb : Coinbase.t) =
    let get_or_initialize pk =
      let initial_account = Account.initialize pk in
      match get_or_create_account_exn t pk (Account.initialize pk) with
      | `Added, location -> (location, initial_account, [pk])
      | `Existed, location -> (location, get t location |> Option.value_exn, [])
    in
    let open Or_error.Let_syntax in
    let%bind proposer_reward, emptys1, receiver_update =
      match fee_transfer with
      | None -> return (Protocols.Coda_praos.coinbase_amount, [], None)
      | Some (receiver, fee) ->
          (* This assertion will pass because of how coinbase super transactions are produced by Ledger_builder.apply_diff *)
          assert (not @@ Public_key.Compressed.equal receiver proposer) ;
          let fee = Amount.of_fee fee in
          let%bind proposer_reward =
            error_opt "Coinbase fee transfer too large"
              (Amount.sub Protocols.Coda_praos.coinbase_amount fee)
          in
          let receiver_location, receiver_account, emptys =
            get_or_initialize receiver
          in
          let%map balance = add_amount receiver_account.balance fee in
          ( proposer_reward
          , emptys
          , Some (receiver_location, {receiver_account with balance}) )
    in
    let proposer_location, proposer_account, emptys2 =
      get_or_initialize proposer
    in
    let%map balance = add_amount proposer_account.balance proposer_reward in
    set t proposer_location {proposer_account with balance} ;
    Option.iter receiver_update ~f:(fun (l, a) -> set t l a) ;
    {Undo.coinbase= cb; previous_empty_accounts= emptys1 @ emptys2}

  (* Don't have to be atomic here because these should never fail. In fact, none of
   the undo functions should ever return an error. This should be fixed in the types. *)
  let undo_coinbase t
      {Undo.coinbase= {proposer; fee_transfer; _}; previous_empty_accounts} =
    let proposer_reward =
      match fee_transfer with
      | None -> Protocols.Coda_praos.coinbase_amount
      | Some (receiver, fee) ->
          let fee = Amount.of_fee fee in
          let receiver_location =
            Or_error.ok_exn (location_of_key' t "receiver" receiver)
          in
          let receiver_account =
            Or_error.ok_exn (get' t "receiver" receiver_location)
          in
          set t receiver_location
            { receiver_account with
              balance=
                Option.value_exn
                  (Balance.sub_amount receiver_account.balance fee) } ;
          Amount.sub Protocols.Coda_praos.coinbase_amount fee
          |> Option.value_exn
    in
    let proposer_location =
      Or_error.ok_exn (location_of_key' t "receiver" proposer)
    in
    let proposer_account =
      Or_error.ok_exn (get' t "proposer" proposer_location)
    in
    set t proposer_location
      { proposer_account with
        balance=
          Option.value_exn
            (Balance.sub_amount proposer_account.balance proposer_reward) } ;
    remove_accounts_exn t previous_empty_accounts

  let undo_transaction ledger
      { Undo.transaction= {payload; sender; signature= _}
      ; previous_empty_accounts
      ; previous_receipt_chain_hash } =
    let sender = Public_key.compress sender in
    let {Transaction.Payload.fee; amount; receiver; nonce} = payload in
    let open Or_error.Let_syntax in
    let%bind sender_location = location_of_key' ledger "sender" sender in
    let%bind sender_account = get' ledger "sender" sender_location in
    let%bind sender_balance' =
      let%bind amount_and_fee = add_fee amount fee in
      add_amount sender_account.balance amount_and_fee
    in
    let%bind () =
      validate_nonces (Account.Nonce.succ nonce) sender_account.nonce
    in
    let sender_account_without_balance_modified =
      { sender_account with
        nonce; receipt_chain_hash= previous_receipt_chain_hash }
    in
    if Public_key.Compressed.equal sender receiver then (
      set ledger sender_location sender_account_without_balance_modified ;
      return () )
    else
      let%bind receiver_location =
        location_of_key' ledger "receiver" receiver
      in
      let%bind receiver_account = get' ledger "receiver" receiver_location in
      let%map receiver_balance' = sub_amount receiver_account.balance amount in
      set ledger sender_location
        {sender_account_without_balance_modified with balance= sender_balance'} ;
      set ledger receiver_location
        {receiver_account with balance= receiver_balance'} ;
      remove_accounts_exn ledger previous_empty_accounts

  let undo : t -> Undo.t -> unit Or_error.t =
   fun ledger undo ->
    let open Or_error.Let_syntax in
    let%map res =
      match undo.varying with
      | Fee_transfer u -> undo_fee_transfer ledger u
      | Transaction u -> undo_transaction ledger u
      | Coinbase c -> undo_coinbase ledger c ; Ok ()
    in
    Debug_assert.debug_assert (fun () ->
        [%test_eq: Ledger_hash.t] undo.previous_hash (merkle_root ledger) ) ;
    res

  let apply_super_transaction ledger (t : Super_transaction.t) =
    let previous_hash = merkle_root ledger in
    Or_error.map
      ( match t with
      | Transaction txn ->
          Or_error.map (apply_transaction ledger txn) ~f:(fun u ->
              Undo.Transaction u )
      | Fee_transfer t ->
          Or_error.map (apply_fee_transfer ledger t) ~f:(fun u ->
              Undo.Fee_transfer u )
      | Coinbase t ->
          Or_error.map (apply_coinbase ledger t) ~f:(fun u -> Undo.Coinbase u)
      )
      ~f:(fun varying -> {Undo.previous_hash; varying})

  let merkle_root_after_transaction_exn ledger transaction =
    let undo = Or_error.ok_exn (apply_transaction ledger transaction) in
    let root = merkle_root ledger in
    Or_error.ok_exn (undo_transaction ledger undo) ;
    root

  let%test "apply fee transfer to the same account" =
    let t = create () in
    let {Keypair.public_key; _} = Signature_lib.Keypair.create () in
    let public_key = Public_key.compress public_key in
    let fee1 = 2 in
    let fee2 = 5 in
    let fee_transfer =
      Fee_transfer.Two
        ((public_key, fee1 |> Fee.of_int), (public_key, fee2 |> Fee.of_int))
    in
    assert (apply_fee_transfer t fee_transfer |> Or_error.is_ok) ;
    let _, account, _ = get_or_create t public_key in
    let expected_account =
      let balance = Balance.of_int (fee1 + fee2) in
      {(Account.initialize public_key) with balance}
    in
    Account.equal expected_account account
end

module Ledger = struct
  include Merkle_ledger.Ledger.Make (Public_key.Compressed) (Account)
            (struct
              type t = Merkle_hash.t [@@deriving sexp, hash, compare, bin_io]

              let merge = Merkle_hash.merge

              let hash_account =
                Fn.compose Merkle_hash.of_digest Account.digest

              let empty_account = hash_account Account.empty
            end)
            (struct
              let depth = ledger_depth
            end)

  type path = Path.t
end

include Make (Ledger)
