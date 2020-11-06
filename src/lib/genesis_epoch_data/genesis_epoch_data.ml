module Data = struct
  type t = {ledger: Genesis_ledger.Packed.t; seed: Coda_base.Epoch_seed.t}
end

type tt = {staking: Data.t; next: Data.t option}

type t = tt option

let for_unit_tests : t = None

let compiled : t = None
