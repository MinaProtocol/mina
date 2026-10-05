module Stable : sig
  module V1 : sig
    type 'challenge t =
          'challenge Mina_wire_types.Pickles_bulletproof_challenge.V1.t =
      { prechallenge : 'challenge }
    [@@deriving sexp, compare, yojson, hash, equal, bin_shape, bin_io]

    include Plonkish_prelude.Sigs.VERSIONED
  end
end

type 'a t = 'a Stable.V1.t = { prechallenge : 'a }
[@@deriving sexp, compare, yojson, hash, equal]

val pack : 'a t -> 'a

val unpack : 'a -> 'a t

val map : 'a t -> f:('a -> 'b) -> 'b t

val typ :
     ('a, 'b) Kimchi_pasta_snarky_backend.Step_impl.Typ.t
  -> ( 'a Kimchi_backend_common.Scalar_challenge.t t
     , 'b Kimchi_backend_common.Scalar_challenge.t t )
     Kimchi_pasta_snarky_backend.Step_impl.Typ.t

val wrap_typ :
     ('a, 'b) Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
  -> ( 'a Kimchi_backend_common.Scalar_challenge.t t
     , 'b Kimchi_backend_common.Scalar_challenge.t t )
     Kimchi_pasta_snarky_backend.Wrap_impl.Typ.t
