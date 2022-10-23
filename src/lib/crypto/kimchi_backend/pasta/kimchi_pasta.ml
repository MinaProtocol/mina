module Basic = Kimchi_pasta_basic

module Pallas_based_plonk = struct
  module Field = Pallas_based_plonk.Field
  module Curve = Pallas_based_plonk.Curve
  module Bigint = Pallas_based_plonk.Bigint

  let field_size = Pallas_based_plonk.field_size

  module Verification_key = Pallas_based_plonk.Verification_key
  module R1CS_constraint_system = Pallas_based_plonk.R1CS_constraint_system
  module Var = Pallas_based_plonk.Var
  module Rounds_vector = Pallas_based_plonk.Rounds_vector
  module Rounds = Pallas_based_plonk.Rounds
  module Keypair = Pallas_based_plonk.Keypair
  module Proof = Pallas_based_plonk.Proof
  module Proving_key = Pallas_based_plonk.Proving_key
  module Oracles = Pallas_based_plonk.Oracles
end

module Vesta_based_plonk = struct
  module Field = Vesta_based_plonk.Field
  module Curve = Vesta_based_plonk.Curve
  module Bigint = Vesta_based_plonk.Bigint

  let field_size = Vesta_based_plonk.field_size

  module Verification_key = Vesta_based_plonk.Verification_key
  module R1CS_constraint_system = Vesta_based_plonk.R1CS_constraint_system
  module Var = Vesta_based_plonk.Var
  module Rounds_vector = Vesta_based_plonk.Rounds_vector
  module Rounds = Vesta_based_plonk.Rounds
  module Keypair = Vesta_based_plonk.Keypair
  module Proof = Vesta_based_plonk.Proof
  module Proving_key = Vesta_based_plonk.Proving_key
  module Oracles = Vesta_based_plonk.Oracles
end

module Pasta = struct
  module Rounds = Pasta.Rounds
  module Bigint256 = Pasta.Bigint256
  module Fp = Pasta.Fp
  module Fq = Pasta.Fq
  module Vesta = Pasta.Vesta
  module Pallas = Pasta.Pallas
  module Precomputed = Pasta.Precomputed
end

module Precomputed = Precomputed
