module Data : sig
  type t = { ledger : Mina_base.Ledger.t Lazy.t; seed : Mina_base.Epoch_seed.t }
end

type tt = { staking : Data.t; next : Data.t option }

type t = tt option

val for_unit_tests : t

val compiled : t
