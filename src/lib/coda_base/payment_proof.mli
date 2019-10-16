open Receipt_chain_database_lib

module Stable : sig
  module V1 : sig
    type t =
      ( Receipt.Chain_hash.Stable.V1.t
      , User_command.Stable.V1.t )
      Payment_proof.Stable.V1.t
    [@@deriving bin_io, eq, sexp, yojson, version]
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving eq, sexp, yojson]

val initial_receipt : t -> Receipt.Chain_hash.t

val payments : t -> User_command.t list
