open Kimchi_backend_common

(* the bn254 field and curve *)

module Bn254_fp = Field.Make (struct
  module Bigint = Kimchi_pasta_basic.Bigint256
  include Bn254_bindings.Bn254Fp
  module Vector = Kimchi_bindings.FieldVectors.Bn254Fp
end)

module Bn254_fq = Field.Make (struct
  module Bigint = Kimchi_pasta_basic.Bigint256
  include Bn254_bindings.Bn254Fq
  module Vector = Kimchi_bindings.FieldVectors.Bn254Fq
end)

module Bn254_curve = struct
  module Params = struct
    open Bn254_fq

    let a = zero

    let b = of_int 2
  end

  include Curve.Make (Bn254_fq) (Bn254_fp) (Params) (Bn254_bindings.Bn254)
end

module Fp_poly_comm = Poly_comm.Make (struct
  module Curve = Bn254_curve
  module Base_field = Bn254_fq

  module Backend = struct
    type t = Curve.Affine.Backend.t Kimchi_types.poly_comm

    let shifted ({ shifted; _ } : t) = shifted

    let unshifted ({ unshifted; _ } : t) = unshifted

    let make :
        Curve.Affine.Backend.t array -> Curve.Affine.Backend.t option -> t =
     fun unshifted shifted : t -> { shifted; unshifted }
  end
end)

(* poseidon params *)

let poseidon_params_fp = Sponge.Params.(map bn128 ~f:Bn254_fp.of_string)
