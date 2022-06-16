open Base
open Mina_base
module Ledger = Mina_ledger.Ledger

module Hashless_ledger = struct
  type t =
    { base : Ledger.t; overlay : (Account.Identifier.t, Account.t) Hashtbl.t }

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
    match loc with
    | Ours key ->
        Hashtbl.set t.overlay ~key ~data:acct
    | Theirs loc -> (
        match Ledger.get t.base loc with
        | Some a ->
            Hashtbl.set t.overlay ~key:(Account.identifier a) ~data:acct
        | None ->
            failwith (msg "set") )

  let get_or_create_account t key account =
    match location_of_account t key with
    | None ->
        set t (Ours key) account ;
        Ok (`Added, Ours key)
    | Some loc ->
        Ok (`Existed, loc)

  let get_or_create_exn ledger aid =
    let action, loc =
      get_or_create_account ledger aid (Account.initialize aid)
      |> Or_error.ok_exn
    in
    (action, Option.value_exn (get ledger loc), loc)

  let create_new_account t account_id account =
    let open Or_error.Let_syntax in
    let%bind action, _ = get_or_create_account t account_id account in
    if [%equal: [ `Existed | `Added ]] action `Existed then
      Or_error.errorf
        !"Could not create a new account with pk \
          %{sexp:Signature_lib.Public_key.Compressed.t}: Account already \
          exists"
        (Account_id.public_key account_id)
    else Ok ()

  let get_or_create t id = Or_error.try_with (fun () -> get_or_create_exn t id)

  let remove_accounts_exn _t =
    failwith "hashless_ledger: bug in transaction_logic"

  (* Without any validation that the hashes match, Mina_transaction_logic doesn't really care what this is. *)
  let merkle_root _t = Ledger_hash.empty_hash

  let create l = { base = l; overlay = Hashtbl.create (module Account_id) }

  let with_ledger ~depth ~f =
    Ledger.with_ledger ~depth ~f:(fun l ->
        let t = create l in
        f t )

  (** Create a new ledger mask 'on top of' the given ledger.

      Warning: For technical reasons, this mask cannot be applied directly to
      the parent ledger; instead, use
      [apply_mask parent_ledger ~masked:this_ledger] to update the parent
      ledger as necessary.
  *)
  let create_masked t = { base = t.base; overlay = Hashtbl.copy t.overlay }

  (** [apply_mask ledger ~masked] applies any updates in [masked] to the ledger
      [ledger]. [masked] should be created by calling [create_masked ledger].

      Warning: This function may behave unexpectedly if [ledger] was modified
      after calling [create_masked], or the given [ledger] was not used to
      create [masked].
  *)
  let apply_mask t ~masked =
    Hashtbl.merge_into ~src:masked.overlay ~dst:t.overlay
      ~f:(fun ~key:_ src _dst -> Set_to src)

  (** Create a new 'empty' ledger. *)
  let empty ~depth () =
    let ledger = Ledger.create_ephemeral ~depth () in
    let res = create ledger in
    (* This ledger should never be modified or read. *)
    Ledger.close ledger ; res
end

include Mina_transaction_logic.Make (Hashless_ledger)

let create = Hashless_ledger.create

let apply_user_command ~constraint_constants ~txn_global_slot l uc =
  Result.map
    ~f:(fun applied_txn ->
      applied_txn.Transaction_applied.Signed_command_applied.common.user_command
        .status )
    (apply_user_command l ~constraint_constants ~txn_global_slot uc)

let apply_transaction' ~constraint_constants ~txn_state_view l t =
  O1trace.sync_thread "apply_transaction" (fun () ->
      apply_transaction ~constraint_constants ~txn_state_view l t )

let apply_transaction ~constraint_constants ~txn_state_view l txn =
  Result.map ~f:Transaction_applied.user_command_status
    (apply_transaction' l ~constraint_constants ~txn_state_view txn)
