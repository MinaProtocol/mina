open Core
open Import

module Poly : sig
  type ('public_key, 'amount) t =
    { source_pk : 'public_key; receiver_pk : 'public_key; amount : 'amount }
  [@@deriving equal, sexp, hash, yojson]

  module Stable : sig
    module V2 : sig
      type nonrec ('pk, 'amount) t
      [@@deriving bin_io, equal, sexp, hash, yojson, version]
    end

    module Latest = V2
  end
  with type ('pk, 'amount) V2.t = ('pk, 'amount) t
end

[%%versioned:
module Stable : sig
  module V2 : sig
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Currency.Amount.Stable.V1.t )
      Poly.Stable.V2.t
    [@@deriving compare, equal, sexp, hash, compare, yojson]
  end
end]

val dummy : t

val token : t -> Token_id.t

val source : t -> Account_id.t

val receiver : t -> Account_id.t

val gen :
     ?source_pk:Public_key.Compressed.t
  -> max_amount:Currency.Amount.t
  -> t Quickcheck.Generator.t
