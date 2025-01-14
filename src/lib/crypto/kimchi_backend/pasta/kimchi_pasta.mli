module Basic = Kimchi_pasta_basic

module Pallas_based_plonk : sig
  module Field = Basic.Fq
  module Curve = Basic.Pallas
  module Bigint = Pallas_based_plonk.Bigint

  val field_size : Pasta_bindings.BigInt256.t

  module Cvar = Pallas_based_plonk.Cvar
  module Verification_key = Pallas_based_plonk.Verification_key
  module R1CS_constraint_system = Pallas_based_plonk.R1CS_constraint_system
  module Constraint = R1CS_constraint_system.Constraint
  module Rounds_vector = Pallas_based_plonk.Rounds_vector
  module Rounds = Pallas_based_plonk.Rounds
  module Keypair = Pallas_based_plonk.Keypair
  module Proof = Pallas_based_plonk.Proof
  module Proving_key = Pallas_based_plonk.Proving_key
  module Oracles = Pallas_based_plonk.Oracles
  module Run_state = Pallas_based_plonk.Run_state
end

module Vesta_based_plonk : sig
  module Field = Vesta_based_plonk.Field
  module Curve = Vesta_based_plonk.Curve
  module Bigint = Vesta_based_plonk.Bigint

  val field_size : Pasta_bindings.BigInt256.t

  module Cvar = Vesta_based_plonk.Cvar
  module Verification_key = Vesta_based_plonk.Verification_key
  module R1CS_constraint_system = Vesta_based_plonk.R1CS_constraint_system
  module Constraint = R1CS_constraint_system.Constraint
  module Rounds_vector = Vesta_based_plonk.Rounds_vector
  module Rounds = Vesta_based_plonk.Rounds
  module Keypair = Vesta_based_plonk.Keypair
  module Proof = Vesta_based_plonk.Proof
  module Proving_key = Vesta_based_plonk.Proving_key
  module Oracles = Vesta_based_plonk.Oracles
  module Run_state = Vesta_based_plonk.Run_state
end

module Pasta : sig
  module Rounds = Basic.Rounds
  module Bigint256 = Basic.Bigint256
  module Fp = Basic.Fp
  module Fq = Basic.Fq
  module Vesta = Basic.Vesta
  module Pallas = Basic.Pallas
end
