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

module Make_typ (Impl : Snarky_backendless.Snark_intf.Run) : sig
  val typ : ('a, 'b) Impl.Typ.t -> ('a t, 'b t) Impl.Typ.t
end

val typ :
     ('a, 'b) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
  -> ('a t, 'b t) Kimchi_pasta_snarky_backend.Step_impl.Typ.t

val wrap_typ :
     ('a, 'b) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
  -> ('a t, 'b t) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t

val map : 'a t -> f:('a -> 'b) -> 'b t
