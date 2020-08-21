open Base

module Hashless_ledger = struct
  type t =
    { base: Ledger.t
    ; overlay: (Account.Identifier.t, Account.t) Hashtbl.t
    ; mutable next_available_token: Token_id.t }

  type location = Ours of Account.Identifier.t | Theirs of Ledger.Location.t

  let msg s =
    s
    ^ ": somehow we got a location that isn't present in the underlying ledger"

  let get t = function
    | Ours key ->
        Hashtbl.find t.overlay key
    | Theirs loc -> (
      match Ledger.get t.base loc with
      | Some a -> (
        match Hashtbl.find t.overlay (Account.identifier a) with
        | None ->
            Some a
        | s ->
            s )
      | None ->
          failwith (msg "get") )

  let location_of_account t key =
    match Hashtbl.find t.overlay key with
    | Some _ ->
        Some (Ours key)
    | None ->
        Option.map
          ~f:(fun d -> Theirs d)
          (Ledger.location_of_account t.base key)

  let set t loc acct =
    if Token_id.(t.next_available_token <= Account.token acct) then
      t.next_available_token <- Token_id.next (Account.token acct) ;
    match loc with
    | Ours key ->
        Hashtbl.set t.overlay ~key ~data:acct
    | Theirs loc -> (
      match Ledger.get t.base loc with
      | Some a ->
          Hashtbl.set t.overlay ~key:(Account.identifier a) ~data:acct
      | None ->
          failwith (msg "set") )

  let get_or_create_account_exn t key account =
    match location_of_account t key with
    | None ->
        set t (Ours key) account ;
        (`Added, Ours key)
    | Some loc ->
        (`Existed, loc)

  let get_or_create ledger aid =
    let action, loc =
      get_or_create_account_exn ledger aid (Account.initialize aid)
    in
    (action, Option.value_exn (get ledger loc), loc)

  let remove_accounts_exn _t =
    failwith "hashless_ledger: bug in transaction_logic, who is calling undo?"

  (* Without undo validating that the hashes match, Transaction_logic doesn't really care what this is. *)
  let merkle_root _t = Ledger_hash.empty_hash

  let create l =
    { base= l
    ; overlay= Hashtbl.create (module Account_id)
    ; next_available_token= Ledger.next_available_token l }

  let with_ledger ~depth ~f =
    Ledger.with_ledger ~depth ~f:(fun l ->
        let t = create l in
        f t )

  let next_available_token {next_available_token; _} = next_available_token

  let set_next_available_token t tid = t.next_available_token <- tid
end

include Transaction_logic.Make (Hashless_ledger)

let create = Hashless_ledger.create

let apply_user_command ~constraint_constants ~txn_global_slot l uc =
  Result.map
    ~f:(fun undo -> undo.Undo.User_command_undo.common.user_command.status)
    (apply_user_command l ~constraint_constants ~txn_global_slot uc)

let apply_transaction ~constraint_constants ~txn_global_slot l txn =
  Result.map ~f:Undo.user_command_status
    (apply_transaction l ~constraint_constants ~txn_global_slot txn)
