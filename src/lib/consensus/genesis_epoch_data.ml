module Data = struct
  type t =
    { ledger : Mina_ledger.Ledger.t Lazy.t; seed : Mina_base.Epoch_seed.t }
end

type tt = { staking : Data.t; next : Data.t option }

type t = tt option

let for_unit_tests : t = None

let compiled : t = None
