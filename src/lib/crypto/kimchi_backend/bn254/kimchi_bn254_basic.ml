(* the bn254 field *)

module Bn254_fp = Field.Make (struct
  module Bigint = Bigint256
  include Bn254_bindings.Bn254Fp
  module Vector = Kimchi_bindings.FieldVectors.Bn254Fp
end)

module Fq = Field.Make (struct
  module Bigint = Bigint256
  include Bn254_bindings.Fq
  module Vector = Kimchi_bindings.FieldVectors.Bn254Fq
end)
