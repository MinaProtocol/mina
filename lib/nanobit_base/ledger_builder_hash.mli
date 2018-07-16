include Data_hash.Small

val of_bytes : string -> t

val dummy : t

module Aux_hash : sig
  include Data_hash.Small

  val of_bytes : string -> t

  val dummy : t
end

val of_aux_and_ledger_hash : Aux_hash.t -> Ledger_hash.t -> t
