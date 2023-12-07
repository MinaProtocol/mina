module Basic = Kimchi_bn254_basic

module Bn254_based_plonk : sig
  module Field = Basic.Bn254_fq
  module Curve = Basic.Bn254
  module Bigint = Bn254_based_plonk.Bigint

  val field_size : Pasta_bindings.BigInt256.t

  module Verification_key = Bn254_based_plonk.Verification_key
  module R1CS_constraint_system = Bn254_based_plonk.R1CS_constraint_system
  module Keypair = Bn254_based_plonk.Keypair
end
