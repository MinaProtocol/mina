open Core
open Import
open Snark_params.Tick

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      ( Ledger_hash.Stable.V1.t
      , Account_id.Stable.V1.t
      , Account.Stable.V2.t
      , Token_id.Stable.V1.t )
      Sparse_ledger_lib.Sparse_ledger.T.Stable.V1.t
    [@@deriving yojson, sexp]

    let to_latest = Fn.id
  end
end]

module Hash = struct
  include Ledger_hash

  let merge = Ledger_hash.merge
end

module Account = struct
  include Account

  let data_hash = Fn.compose Ledger_hash.of_digest Account.digest
end

module M =
  Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Token_id) (Account_id) (Account)

type account_state = [ `Added | `Existed ] [@@deriving equal]

module L = struct
  type t = M.t ref

  type location = int

  let get : t -> location -> Account.t option =
   fun t loc ->
    Option.try_with (fun () ->
        let account = M.get_exn !t loc in
        if Public_key.Compressed.(equal empty account.public_key) then None
        else Some account)
    |> Option.bind ~f:Fn.id

  let location_of_account : t -> Account_id.t -> location option =
   fun t id -> Option.try_with (fun () -> M.find_index_exn !t id)

  let set : t -> location -> Account.t -> unit =
   fun t loc a -> t := M.set_exn !t loc a

  let get_or_create_exn :
      t -> Account_id.t -> account_state * Account.t * location =
   fun t id ->
    let loc = M.find_index_exn !t id in
    let account = M.get_exn !t loc in
    if Public_key.Compressed.(equal empty account.public_key) then (
      let public_key = Account_id.public_key id in
      let account' : Account.t =
        { account with
          delegate = Some public_key
        ; public_key
        ; token_id = Account_id.token_id id
        }
      in
      set t loc account' ;
      (`Added, account', loc) )
    else (`Existed, account, loc)

  let get_or_create t id = Or_error.try_with (fun () -> get_or_create_exn t id)

  let get_or_create_account :
      t -> Account_id.t -> Account.t -> (account_state * location) Or_error.t =
   fun t id to_set ->
    Or_error.try_with (fun () ->
        let loc = M.find_index_exn !t id in
        let a = M.get_exn !t loc in
        if Public_key.Compressed.(equal empty a.public_key) then (
          set t loc to_set ;
          (`Added, loc) )
        else (`Existed, loc))

  let remove_accounts_exn : t -> Account_id.t list -> unit =
   fun _t _xs -> failwith "remove_accounts_exn: not implemented"

  let merkle_root : t -> Ledger_hash.t = fun t -> M.merkle_root !t

  let with_ledger : depth:int -> f:(t -> 'a) -> 'a =
   fun ~depth:_ ~f:_ -> failwith "with_ledger: not implemented"

  let next_available_token : t -> Token_id.t =
   fun t -> M.next_available_token !t

  let set_next_available_token : t -> Token_id.t -> unit =
   fun t token -> t := { !t with next_available_token = token }
end

module T = Transaction_logic.Make (L)

[%%define_locally
M.
  ( of_hash
  , to_yojson
  , of_yojson
  , get_exn
  , path_exn
  , set_exn
  , find_index_exn
  , add_path
  , merkle_root
  , iteri
  , next_available_token )]

let of_root ~depth ~next_available_token (h : Ledger_hash.t) =
  of_hash ~depth ~next_available_token
    (Ledger_hash.of_digest (h :> Random_oracle.Digest.t))

let of_ledger_root ledger =
  of_root ~depth:(Ledger.depth ledger)
    ~next_available_token:(Ledger.next_available_token ledger)
    (Ledger.merkle_root ledger)

let of_any_ledger (ledger : Ledger.Any_ledger.witness) =
  Ledger.Any_ledger.M.foldi ledger
    ~init:
      (of_root
         ~depth:(Ledger.Any_ledger.M.depth ledger)
         ~next_available_token:(Ledger.Any_ledger.M.next_available_token ledger)
         (Ledger.Any_ledger.M.merkle_root ledger))
    ~f:(fun _addr sparse_ledger account ->
      let loc =
        Option.value_exn
          (Ledger.Any_ledger.M.location_of_account ledger
             (Account.identifier account))
      in
      add_path sparse_ledger
        (Ledger.Any_ledger.M.merkle_path ledger loc)
        (Account.identifier account)
        (Option.value_exn (Ledger.Any_ledger.M.get ledger loc)))

let of_ledger_subset_exn (oledger : Ledger.t) keys =
  let ledger = Ledger.copy oledger in
  let _, sparse =
    List.fold keys
      ~f:(fun (new_keys, sl) key ->
        match Ledger.location_of_account ledger key with
        | Some loc ->
            ( new_keys
            , add_path sl
                (Ledger.merkle_path ledger loc)
                key
                ( Ledger.get ledger loc
                |> Option.value_exn ?here:None ?error:None ?message:None ) )
        | None ->
            let path, acct = Ledger.create_empty_exn ledger key in
            (key :: new_keys, add_path sl path key acct))
      ~init:([], of_ledger_root ledger)
  in
  Debug_assert.debug_assert (fun () ->
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sparse :> Random_oracle.Digest.t) |> Ledger_hash.of_hash)) ;
  sparse

let of_ledger_index_subset_exn (ledger : Ledger.Any_ledger.witness) indexes =
  List.fold indexes
    ~init:
      (of_root
         ~depth:(Ledger.Any_ledger.M.depth ledger)
         ~next_available_token:(Ledger.Any_ledger.M.next_available_token ledger)
         (Ledger.Any_ledger.M.merkle_root ledger))
    ~f:(fun acc i ->
      let account = Ledger.Any_ledger.M.get_at_index_exn ledger i in
      add_path acc
        (Ledger.Any_ledger.M.merkle_path_at_index_exn ledger i)
        (Account.identifier account)
        account)

let%test_unit "of_ledger_subset_exn with keys that don't exist works" =
  let keygen () =
    let privkey = Private_key.create () in
    (privkey, Public_key.of_private_key_exn privkey |> Public_key.compress)
  in
  Ledger.with_ledger
    ~depth:Genesis_constants.Constraint_constants.for_unit_tests.ledger_depth
    ~f:(fun ledger ->
      let _, pub1 = keygen () in
      let _, pub2 = keygen () in
      let aid1 = Account_id.create pub1 Token_id.default in
      let aid2 = Account_id.create pub2 Token_id.default in
      let sl = of_ledger_subset_exn ledger [ aid1; aid2 ] in
      [%test_eq: Ledger_hash.t]
        (Ledger.merkle_root ledger)
        ((merkle_root sl :> Random_oracle.Digest.t) |> Ledger_hash.of_hash))

let get_or_initialize_exn account_id t idx =
  let account = get_exn t idx in
  if Public_key.Compressed.(equal empty account.public_key) then
    let public_key = Account_id.public_key account_id in
    let token_id = Account_id.token_id account_id in
    let delegate =
      (* Only allow delegation if this account is for the default token. *)
      if Token_id.(equal default) token_id then Some public_key else None
    in
    ( `Added
    , { account with
        delegate
      ; public_key
      ; token_id = Account_id.token_id account_id
      } )
  else (`Existed, account)

let has_locked_tokens_exn ~global_slot ~account_id t =
  let idx = find_index_exn t account_id in
  let _, account = get_or_initialize_exn account_id t idx in
  Account.has_locked_tokens ~global_slot account

let apply_transaction_logic f t x =
  let open Or_error.Let_syntax in
  let t' = ref t in
  let%map app = f t' x in
  (!t', app)

let apply_user_command ~constraint_constants ~txn_global_slot =
  apply_transaction_logic
    (T.apply_user_command ~constraint_constants ~txn_global_slot)

let apply_transaction' = T.apply_transaction

let apply_transaction ~constraint_constants ~txn_state_view =
  apply_transaction_logic
    (T.apply_transaction ~constraint_constants ~txn_state_view)

let merkle_root t = Ledger_hash.of_hash (merkle_root t :> Random_oracle.Digest.t)

let depth t = M.depth t

let handler t =
  let ledger = ref t in
  let path_exn idx =
    List.map (path_exn !ledger idx) ~f:(function `Left h -> h | `Right h -> h)
  in
  stage (fun (With { request; respond }) ->
      match request with
      | Ledger_hash.Get_element idx ->
          let elt = get_exn !ledger idx in
          let path = (path_exn idx :> Random_oracle.Digest.t list) in
          respond (Provide (elt, path))
      | Ledger_hash.Get_path idx ->
          let path = (path_exn idx :> Random_oracle.Digest.t list) in
          respond (Provide path)
      | Ledger_hash.Set (idx, account) ->
          ledger := set_exn !ledger idx account ;
          respond (Provide ())
      | Ledger_hash.Find_index pk ->
          let index = find_index_exn !ledger pk in
          respond (Provide index)
      | _ ->
          unhandled)
