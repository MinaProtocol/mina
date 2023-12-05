open Kimchi_backend_common
open Kimchi_pasta_basic

(* the bn254 field and curve *)

module Bn254_fp = Field.Make (struct
  module Bigint = Bigint256
  include Bn254_bindings.Bn254Fp
  module Vector = Kimchi_bindings.FieldVectors.Bn254Fp
end)

module Bn254_fq = Field.Make (struct
  module Bigint = Bigint256
  include Bn254_bindings.Bn254Fq
  module Vector = Kimchi_bindings.FieldVectors.Bn254Fq
end)

module Bn254 = struct
  module Params = struct
    open Bn254_fq

    let a = zero

    let b = of_int 2
  end

  include Curve.Make (Bn254_fq) (Bn254_fp) (Params) (Bn254_bindings.Bn254)
end
