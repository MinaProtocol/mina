open Core_kernel

type t = Ledger.t

let create ~parent =
  let parent = Immutable_ledger.unsafe_to_ledger parent in
  Ledger.register_mask parent
    (Ledger.Mask.create ~depth:(Ledger.depth parent) ())

let freeze ~loc t =
  Immutable_ledger.unsafe_of_ledger (Ledger.Mask.Attached.move ~loc t)

let discard = Ledger.Mask.Attached.discard

let depth = Ledger.depth

let merkle_root = Ledger.merkle_root

let location_of_account = Ledger.location_of_account

let get = Ledger.get

let set = Ledger.set

let get_or_create_account = Ledger.get_or_create_account

let unsafe_preload_accounts_from_parent =
  Ledger.unsafe_preload_accounts_from_parent

let unsafe_of_ledger = Fn.id

let unsafe_to_ledger = Fn.id
