module Stable : sig
  module V2 : sig
    type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }
    [@@deriving yojson, bin_io, version, sexp, compare, equal, hash]
  end

  module Latest = V2
end

type 'f t = 'f Kimchi_types.scalar_challenge = { inner : 'f }
[@@deriving yojson, sexp, compare, equal, hash]

val create : 'a -> 'a t

val typ :
     ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ('a t, 'b t, 'c) Snarky_backendless.Typ.t

val map : 'a t -> f:('a -> 'b) -> 'b t
