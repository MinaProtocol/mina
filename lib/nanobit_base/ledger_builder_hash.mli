include Data_hash.Small

val of_bytes : string -> t

val dummy : t

module Aux_hash : sig
  include Data_hash.Small

  val of_bytes : string -> t

  val dummy : t
end

type sibling_hash [@@deriving bin_io]

type ledger_builder_aux_hash [@@deriving bin_io]

val of_aux_and_sibling_hash : Aux_hash.t -> sibling_hash -> t
