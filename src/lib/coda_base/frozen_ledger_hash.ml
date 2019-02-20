include Ledger_hash

let of_ledger_hash (h : Ledger_hash.t) : t = h

let to_ledger_hash (t : t) : Ledger_hash.t = t
