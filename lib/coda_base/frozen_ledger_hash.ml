open Core_kernel
module Ledger_hash = Ledger_hash
include Ledger_hash

let of_ledger_hash = Fn.id
