open Base
open Signature_lib

module Hashless_ledger = struct
  type t = {base: Ledger.t; overlay: (Account.key, Account.t) Hashtbl.t}

  type location = Ours of Account.key | Theirs of Ledger.Location.t

  let msg s =
    s
    ^ ": somehow we got a location that isn't present in the underlying ledger"

  let get t = function
    | Ours key -> Hashtbl.find t.overlay key
    | Theirs loc -> (
      match Ledger.get t.base loc with
      | Some a -> (
        match Hashtbl.find t.overlay (Account.public_key a) with
        | None -> Some a
        | s -> s )
      | None -> failwith (msg "get") )

  let location_of_key t key =
    match Hashtbl.find t.overlay key with
    | Some _ -> Some (Ours key)
    | None ->
        Option.map ~f:(fun d -> Theirs d) (Ledger.location_of_key t.base key)

  let set t loc acct =
    match loc with
    | Ours key -> Hashtbl.set t.overlay ~key ~data:acct
    | Theirs loc -> (
      match Ledger.get t.base loc with
      | Some a -> Hashtbl.set t.overlay ~key:(Account.public_key a) ~data:acct
      | None -> failwith (msg "set") )

  let get_or_create_account_exn t key account =
    match location_of_key t key with
    | None ->
        set t (Ours key) account ;
        (`Added, Ours key)
    | Some loc -> (`Existed, loc)

  let get_or_create ledger key =
    let key, loc =
      match get_or_create_account_exn ledger key (Account.initialize key) with
      | `Existed, loc -> ([], loc)
      | `Added, loc -> ([key], loc)
    in
    (key, get ledger loc |> Option.value_exn, loc)

  let remove_accounts_exn _t =
    failwith "hashless_ledger: bug in transaction_logic, who is calling undo?"

  (* Without undo validating that the hashes match, Transaction_logic doesn't really care what this is. *)
  let merkle_root t = Ledger_hash.empty_hash

  let create l =
    {base= l; overlay= Hashtbl.create (module Public_key.Compressed)}

  let with_ledger ~f =
    Ledger.with_ledger ~f:(fun l ->
        let t = create l in
        f t )
end

include Transaction_logic.Make (Hashless_ledger)

type ledger = Hashless_ledger.t

let create = Hashless_ledger.create

let apply_user_command l uc =
  Result.map ~f:(Fn.const ()) (apply_user_command l uc)

let apply_transaction l txn =
  Result.map ~f:(Fn.const ()) (apply_transaction l txn)
