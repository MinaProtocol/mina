open Core
open Snark_params
open Currency
open Signature_lib
open Merkle_ledger

module Depth = struct
  let depth = ledger_depth
end

module Location0 : Merkle_ledger.Location_intf.S =
  Merkle_ledger.Location.Make (Depth)

module Location_at_depth = Location0

module Key = struct
  module T = struct
    type t = Account.key [@@deriving sexp, bin_io, compare, hash, eq]
  end

  let empty = Account.empty.public_key

  include T
  include Hashable.Make_binable (T)
end

module Kvdb : Intf.Key_value_database = Rocksdb_database

module Storage_locations : Intf.Storage_locations = struct
  let stack_db_file = "coda_stack_db"

  let key_value_db_dir = "coda_key_value_db"
end

module Hash = struct
  type t = Ledger_hash.t [@@deriving bin_io, sexp]

  let merge = Ledger_hash.merge

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = hash_account Account.empty
end

module Db :
  Merkle_ledger.Database_intf.S
  with module Location = Location_at_depth
  with module Addr = Location_at_depth.Addr
  with type root_hash := Ledger_hash.t
   and type hash := Ledger_hash.t
   and type account := Account.t
   and type key := Public_key.Compressed.t =
  Database.Make (Key) (Account) (Hash) (Depth) (Location_at_depth) (Kvdb)
    (Storage_locations)

module Any_ledger :
  Merkle_ledger.Any_ledger.S
  with module Location = Location_at_depth
  with type account := Account.t
   and type key := Key.t
   and type hash := Hash.t =
  Merkle_ledger.Any_ledger.Make_base (Key) (Account) (Hash) (Location_at_depth)
    (Depth)

module Mask :
  Merkle_mask.Masking_merkle_tree_intf.S
  with module Location = Location_at_depth
  with module Addr = Location_at_depth.Addr
   and module Attached.Addr = Location_at_depth.Addr
  with type account := Account.t
   and type key := Key.t
   and type hash := Hash.t
   and type location := Location_at_depth.t
   and type parent := Any_ledger.M.t =
  Merkle_mask.Masking_merkle_tree.Make (Key) (Account) (Hash)
    (Location_at_depth)
    (Any_ledger.M)

module Maskable :
  Merkle_mask.Maskable_merkle_tree_intf.S
  with module Location = Location_at_depth
  with module Addr = Location_at_depth.Addr
  with type account := Account.t
   and type key := Key.t
   and type hash := Hash.t
   and type root_hash := Hash.t
   and type unattached_mask := Mask.t
   and type attached_mask := Mask.Attached.t
   and type t := Any_ledger.M.t =
  Merkle_mask.Maskable_merkle_tree.Make (Key) (Account) (Hash)
    (Location_at_depth)
    (Any_ledger.M)
    (Mask)

include Mask.Attached

type maskable_ledger = t

(* Mask.Attached.create () fails, can't create an attached mask directly
   shadow create in order to create an attached mask
*)
let create ?directory_name () =
  let maskable = Db.create ?directory_name () in
  let casted = Any_ledger.cast (module Db) maskable in
  let mask = Mask.create () in
  Maskable.register_mask casted mask

let of_database db =
  let casted = Any_ledger.cast (module Db) db in
  let mask = Mask.create () in
  Maskable.register_mask casted mask

(* Mask.Attached.create () fails, can't create an attached mask directly
   shadow create in order to create an attached mask
*)
let create ?directory_name () = of_database (Db.create ?directory_name ())

let with_ledger ~f =
  let ledger = create () in
  try
    let result = f ledger in
    destroy ledger ; result
  with exn -> destroy ledger ; raise exn

let packed t = Any_ledger.cast (module Mask.Attached) t

let register_mask t mask = Maskable.register_mask (packed t) mask

let unregister_mask_exn t mask = Maskable.unregister_mask_exn (packed t) mask

(* TODO: Implement the serialization/deserialization *)
let unattached_mask_of_serializable _ = failwith "unimplmented"

let serializable_of_t _ = failwith "unimplented"

type serializable = int [@@deriving bin_io]

type unattached_mask = Mask.t

type attached_mask = Mask.Attached.t

(* inside MaskedLedger, the functor argument has assigned to location, account, and path
   but the module signature for the functor result wants them, so we declare them here *)
type location = Location.t

(* TODO: Don't allocate: see Issue #1191 *)
let fold_until t ~init ~f ~finish =
  let accounts = to_list t in
  List.fold_until accounts ~init ~f ~finish

let create_new_account_exn t pk account =
  let action, _ = get_or_create_account_exn t pk account in
  assert (action = `Added)

(* shadows definition in MaskedLedger, extra assurance hash is of right type  *)
let merkle_root t =
  Ledger_hash.of_hash (merkle_root t :> Tick.Pedersen.Digest.t)

let error s = Or_error.errorf "Ledger.apply_transaction: %s" s

let error_opt e = Option.value_map ~default:(error e) ~f:Or_error.return

let get' ledger tag location =
  error_opt (sprintf "%s account not found" tag) (get ledger location)

let location_of_key' ledger tag key =
  error_opt (sprintf "%s location not found" tag) (location_of_key ledger key)

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

let create_empty ledger key =
  let start_hash = merkle_root ledger in
  match get_or_create_account_exn ledger key Account.empty with
  | `Existed, _ -> failwith "create_empty for a key already present"
  | `Added, new_loc ->
      Debug_assert.debug_assert (fun () ->
          [%test_eq: Ledger_hash.t] start_hash (merkle_root ledger) ) ;
      (merkle_path ledger new_loc, Account.empty)

module Undo = struct
  module UC = User_command

  module User_command = struct
    module Common = struct
      type t =
        { user_command: User_command.t
        ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
      [@@deriving sexp, bin_io]
    end

    module Body = struct
      type t =
        | Payment of {previous_empty_accounts: Public_key.Compressed.t list}
        | Stake_delegation of {previous_delegate: Public_key.Compressed.t}
      [@@deriving sexp, bin_io]
    end

    type t = {common: Common.t; body: Body.t} [@@deriving sexp, bin_io]
  end

  type fee_transfer =
    { fee_transfer: Fee_transfer.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type coinbase =
    { coinbase: Coinbase.t
    ; previous_empty_accounts: Public_key.Compressed.t list }
  [@@deriving sexp, bin_io]

  type varying =
    | User_command of User_command.t
    | Fee_transfer of fee_transfer
    | Coinbase of coinbase
  [@@deriving sexp, bin_io]

  type t = {previous_hash: Ledger_hash.t; varying: varying}
  [@@deriving sexp, bin_io]

  let transaction : t -> Transaction.t Or_error.t =
   fun {varying; _} ->
    let open Or_error.Let_syntax in
    match varying with
    | User_command tr ->
        Option.value_map ~default:(Or_error.error_string "Bad signature")
          (UC.check tr.common.user_command) ~f:(fun x ->
            Ok (Transaction.User_command x) )
    | Fee_transfer f -> Ok (Fee_transfer f.fee_transfer)
    | Coinbase c -> Ok (Coinbase c.coinbase)
end

(* someday: It would probably be better if we didn't modify the receipt chain hash
 in the case that the sender is equal to the receiver, but it complicates the SNARK, so
 we don't for now. *)
let apply_user_command_unchecked ledger
    ({payload; sender; signature= _} as user_command : User_command.t) =
  let sender = Public_key.compress sender in
  let nonce = User_command.Payload.nonce payload in
  let open Or_error.Let_syntax in
  let%bind sender_location = location_of_key' ledger "" sender in
  (* We unconditionally deduct the fee if this transaction succeeds *)
  let%bind sender_account, common =
    let%bind account = get' ledger "sender" sender_location in
    let%bind balance =
      sub_amount account.balance
        (Amount.of_fee (User_command.Payload.fee payload))
    in
    let common : Undo.User_command.Common.t =
      {user_command; previous_receipt_chain_hash= account.receipt_chain_hash}
    in
    let%bind () = validate_nonces nonce account.nonce in
    let account =
      { account with
        nonce= Account.Nonce.succ account.nonce
      ; receipt_chain_hash=
          Receipt.Chain_hash.cons payload account.receipt_chain_hash }
    in
    return ({account with balance}, common)
  in
  match User_command.Payload.body payload with
  | Stake_delegation (Set_delegate {new_delegate}) ->
      set ledger sender_location {sender_account with delegate= new_delegate} ;
      return
        { Undo.User_command.common
        ; body= Stake_delegation {previous_delegate= sender_account.delegate}
        }
  | Payment {Payment_payload.amount; receiver} ->
      let%bind sender_balance' = sub_amount sender_account.balance amount in
      let undo emptys : Undo.User_command.t =
        {common; body= Payment {previous_empty_accounts= emptys}}
      in
      if Public_key.Compressed.equal sender receiver then (
        ignore @@ set ledger sender_location sender_account ;
        return (undo []) )
      else
        let previous_empty_accounts, receiver_account, receiver_location =
          get_or_create ledger receiver
        in
        let%map receiver_balance' =
          add_amount receiver_account.balance amount
        in
        set ledger sender_location
          {sender_account with balance= sender_balance'} ;
        set ledger receiver_location
          {receiver_account with balance= receiver_balance'} ;
        undo previous_empty_accounts

let apply_user_command ledger
    (user_command : User_command.With_valid_signature.t) =
  apply_user_command_unchecked ledger (user_command :> User_command.t)

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
let apply_coinbase t
    ({proposer; fee_transfer; amount= coinbase_amount} as cb : Coinbase.t) =
  let get_or_initialize pk =
    let initial_account = Account.initialize pk in
    match get_or_create_account_exn t pk (Account.initialize pk) with
    | `Added, location -> (location, initial_account, [pk])
    | `Existed, location -> (location, get t location |> Option.value_exn, [])
  in
  let open Or_error.Let_syntax in
  let%bind proposer_reward, emptys1, receiver_update =
    match fee_transfer with
    | None -> return (coinbase_amount, [], None)
    | Some (receiver, fee) ->
        (* This assertion will pass because of how coinbase is produced by Staged_ledger.apply_diff *)
        assert (not @@ Public_key.Compressed.equal receiver proposer) ;
        let fee = Amount.of_fee fee in
        let%bind proposer_reward =
          error_opt "Coinbase fee transfer too large"
            (Amount.sub coinbase_amount fee)
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
    { Undo.coinbase= {proposer; fee_transfer; amount= coinbase_amount}
    ; previous_empty_accounts } =
  let proposer_reward =
    match fee_transfer with
    | None -> coinbase_amount
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
        Amount.sub coinbase_amount fee |> Option.value_exn
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

let undo_user_command ledger
    { Undo.User_command.common=
        { user_command= {payload; sender; signature= _}
        ; previous_receipt_chain_hash }
    ; body } =
  let sender = Public_key.compress sender in
  let nonce = User_command.Payload.nonce payload in
  let open Or_error.Let_syntax in
  let%bind sender_location = location_of_key' ledger "sender" sender in
  let%bind sender_account =
    let%bind account = get' ledger "sender" sender_location in
    let%bind balance =
      add_amount account.balance
        (Amount.of_fee (User_command.Payload.fee payload))
    in
    let%bind () = validate_nonces (Account.Nonce.succ nonce) account.nonce in
    return
      { account with
        balance; nonce; receipt_chain_hash= previous_receipt_chain_hash }
  in
  match (User_command.Payload.body payload, body) with
  | Stake_delegation (Set_delegate _), Stake_delegation {previous_delegate} ->
      set ledger sender_location
        {sender_account with delegate= previous_delegate} ;
      return ()
  | Payment {amount; receiver}, Payment {previous_empty_accounts} ->
      let%bind sender_balance' = add_amount sender_account.balance amount in
      if Public_key.Compressed.equal sender receiver then (
        set ledger sender_location sender_account ;
        return () )
      else
        let%bind receiver_location =
          location_of_key' ledger "receiver" receiver
        in
        let%bind receiver_account = get' ledger "receiver" receiver_location in
        let%map receiver_balance' =
          sub_amount receiver_account.balance amount
        in
        set ledger sender_location
          {sender_account with balance= sender_balance'} ;
        set ledger receiver_location
          {receiver_account with balance= receiver_balance'} ;
        remove_accounts_exn ledger previous_empty_accounts
  | _, _ -> failwith "Undo/command mismatch"

let undo : t -> Undo.t -> unit Or_error.t =
 fun ledger undo ->
  let open Or_error.Let_syntax in
  let%map res =
    match undo.varying with
    | Fee_transfer u -> undo_fee_transfer ledger u
    | User_command u -> undo_user_command ledger u
    | Coinbase c -> undo_coinbase ledger c ; Ok ()
  in
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t] undo.previous_hash (merkle_root ledger) ) ;
  res

let apply_transaction ledger (t : Transaction.t) =
  let previous_hash = merkle_root ledger in
  Or_error.map
    ( match t with
    | User_command txn ->
        Or_error.map (apply_user_command ledger txn) ~f:(fun u ->
            Undo.User_command u )
    | Fee_transfer t ->
        Or_error.map (apply_fee_transfer ledger t) ~f:(fun u ->
            Undo.Fee_transfer u )
    | Coinbase t ->
        Or_error.map (apply_coinbase ledger t) ~f:(fun u -> Undo.Coinbase u) )
    ~f:(fun varying -> {Undo.previous_hash; varying})

let merkle_root_after_user_command_exn ledger payment =
  let undo = Or_error.ok_exn (apply_user_command ledger payment) in
  let root = merkle_root ledger in
  Or_error.ok_exn (undo_user_command ledger undo) ;
  root

let%test "apply fee transfer to the same account" =
  with_ledger ~f:(fun t ->
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
      Account.equal expected_account account )
