open Core_kernel

type t = Ledger.t

let of_any_ledger = Ledger.of_any_ledger

let depth = Ledger.depth

let merkle_root = Ledger.merkle_root

let num_accounts = Ledger.num_accounts

let location_of_account = Ledger.location_of_account

let get = Ledger.get

let to_list = Ledger.to_list

let commit_into_parent = Ledger.commit_and_replace_parent

let unsafe_of_ledger = Fn.id

let unsafe_to_ledger = Fn.id
