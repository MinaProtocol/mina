module Data : sig
  module Stable : sig
    module V1 : sig
      type t = { constraints : int } [@@deriving yojson]

      include Pickles_types.Sigs.VERSIONED
    end
  end

  type t = Stable.V1.t = { constraints : int } [@@deriving yojson]
end

module Stable : sig
  module V2 : sig
    type t =
      { commitments :
          Backend.Tock.Curve.Affine.t
          Pickles_types.Plonk_verification_key_evals.t
      ; index : Impls.Wrap.Verification_key.t
      ; data : Data.t
      }
    [@@deriving fields, to_yojson, bin_shape, bin_io]

    include Pickles_types.Sigs.VERSIONED
  end

  module Latest = V2
end

type t = Stable.Latest.t =
  { commitments :
      Backend.Tock.Curve.Affine.t Pickles_types.Plonk_verification_key_evals.t
  ; index : Impls.Wrap.Verification_key.t
  ; data : Data.t
  }
[@@deriving fields, to_yojson]

val dummy_commitments : 'a -> 'a Pickles_types.Plonk_verification_key_evals.t

val dummy : Stable.Latest.t lazy_t
