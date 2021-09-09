include Ledger_hash_intf.S with type var = Frozen_ledger_hash0.var

val of_ledger_hash : Ledger_hash.t -> t

val to_ledger_hash : t -> Ledger_hash.t
