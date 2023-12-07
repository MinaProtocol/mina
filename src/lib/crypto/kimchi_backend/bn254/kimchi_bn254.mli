module Basic = Kimchi_bn254_basic

module Bn254_based_plonk : sig
  module Field = Basic.Bn254_fq
  module Curve = Basic.Bn254
  module Bigint = Bn254_based_plonk.Bigint

  val field_size : Pasta_bindings.BigInt256.t

  module Verification_key = Bn254_based_plonk.Verification_key
  module R1CS_constraint_system = Bn254_based_plonk.R1CS_constraint_system
  module Keypair = Bn254_based_plonk.Keypair
  module Proving_key = Bn254_based_plonk.Proving_key
end

module Bn254 : sig
  module Fp = Bn254.Bn254_fp
  module Fq = Bn254.Bn254_fq
  module Curve = Bn254.Curve
end

module Impl : sig
  module Verification_key = Bn254_based_plonk.Verification_key
  module Proving_key = Bn254_based_plonk.Proving_key
  
  module Keypair : sig
    type t = { pk : Proving_key.t; vk : Verification_key.t } [@@deriving fields]

    val create : pk:Proving_key.t -> vk:Verification_key.t -> t

    val generate :
         prev_challenges:int
      -> Kimchi_bn254_constraint_system.Bn254_constraint_system.t
      -> t
  end
end
