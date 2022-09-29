module Stable : sig
  module V1 : sig
    type 'challenge t =
      'challenge Mina_wire_types.Pickles_bulletproof_challenge.V1.t
    [@@deriving sexp, compare, yojson, hash, equal]

    include Pickles_types.Sigs.Binable.S1 with type 'a t := 'a t

    include Pickles_types.Sigs.VERSIONED
  end
end

type 'a t = 'a Stable.V1.t [@@deriving sexp, compare, yojson, hash, equal]

val pack : 'a t -> 'a

val unpack : 'a -> 'a t

val map : 'a t -> f:('a -> 'b) -> 'b t

val typ :
     ('a, 'b, 'c) Snarky_backendless.Typ.t
  -> ( 'a Kimchi_backend_common.Scalar_challenge.t t
     , 'b Kimchi_backend_common.Scalar_challenge.t t
     , 'c )
     Snarky_backendless.Typ.t
