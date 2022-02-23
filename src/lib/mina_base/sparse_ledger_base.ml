open Core
open Mina_base_import
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

type sparse_ledger = t [@@deriving sexp, to_yojson]

module Hash = struct
  include Ledger_hash

  let merge = Ledger_hash.merge
end

module Account = struct
  include Account

  let data_hash = Fn.compose Ledger_hash.of_digest Account.digest
end

module Global_state = struct
  type t =
    { ledger : sparse_ledger
    ; fee_excess : Currency.Amount.Signed.t
    ; protocol_state : Snapp_predicate.Protocol_state.View.t
    }
  [@@deriving sexp, to_yojson]
end

module GS = Global_state
module M =
  Sparse_ledger_lib.Sparse_ledger.Make (Hash) (Token_id) (Account_id) (Account)

type account_state = [ `Added | `Existed ] [@@deriving equal]

(** Create a new 'empty' ledger.
    This ledger has an invalid root hash, and cannot be used except as a
    placeholder.
*)
let empty ~depth () =
  M.of_hash
    ~next_available_token:Token_id.(next default)
    ~depth Outside_hash_image.t

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

  let create_new_account t id to_set =
    get_or_create_account t id to_set |> Or_error.map ~f:ignore

  let remove_accounts_exn : t -> Account_id.t list -> unit =
   fun _t _xs -> failwith "remove_accounts_exn: not implemented"

  let merkle_root : t -> Ledger_hash.t = fun t -> M.merkle_root !t

  let with_ledger : depth:int -> f:(t -> 'a) -> 'a =
   fun ~depth:_ ~f:_ -> failwith "with_ledger: not implemented"

  let next_available_token : t -> Token_id.t =
   fun t -> M.next_available_token !t

  let set_next_available_token : t -> Token_id.t -> unit =
   fun t token -> t := { !t with next_available_token = token }

  (** Create a new ledger mask 'on top of' the given ledger.

      Warning: For technical reasons, this mask cannot be applied directly to
      the parent ledger; instead, use
      [apply_mask parent_ledger ~masked:this_ledger] to update the parent
      ledger as necessary.
  *)
  let create_masked t = ref !t

  (** [apply_mask ledger ~masked] applies any updates in [masked] to the ledger
      [ledger]. [masked] should be created by calling [create_masked ledger].

      Warning: This function may behave unexpectedly if [ledger] was modified
      after calling [create_masked], or the given [ledger] was not used to
      create [masked].
  *)
  let apply_mask t ~masked = t := !masked

  (** Create a new 'empty' ledger.
      This ledger has an invalid root hash, and cannot be used except as a
      placeholder.
  *)
  let empty ~depth () = ref (empty ~depth ())
end

module T = Transaction_logic.Make (L)

[%%define_locally
M.
  ( of_hash
  , to_yojson
  , get_exn
  , path_exn
  , set_exn
  , find_index_exn
  , add_path
  , merkle_root
  , iteri
  , next_available_token )]

let apply_parties_unchecked_with_states ~constraint_constants ~state_view
    ~fee_excess ledger c =
  let open T in
  apply_parties_unchecked_aux ~constraint_constants ~state_view ~fee_excess
    (ref ledger) c ~init:[]
    ~f:(fun acc ({ ledger; fee_excess; protocol_state }, local_state) ->
      ( { GS.ledger = !ledger; fee_excess; protocol_state }
      , { local_state with ledger = !(local_state.ledger) } )
      :: acc)
  |> Result.map ~f:(fun (party_applied, states) ->
         (* We perform a [List.rev] here to ensure that the states are in order
            wrt. the parties that generated the states.
         *)
         (party_applied, List.rev states))

let of_root ~depth ~next_available_token (h : Ledger_hash.t) =
  of_hash ~depth ~next_available_token
    (Ledger_hash.of_digest (h :> Random_oracle.Digest.t))

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
