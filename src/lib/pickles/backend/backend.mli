module Tick : sig
  module Field = Pasta__.Basic.Fp
  module Curve = Pasta__.Basic.Vesta
  module Bigint = Pasta__Vesta_based_plonk.Bigint

  val field_size : Pasta__Vesta_based_plonk.Bigint.R.t

  module Verification_key = Pasta__Vesta_based_plonk.Verification_key
  module R1CS_constraint_system =
    Pasta__Vesta_based_plonk.R1CS_constraint_system
  module Var = Zexe_backend_common.Var

  val lagrange : int -> Marlin_plonk_bindings.Pasta_fp_urs.Poly_comm.t array

  val with_lagrange :
       (   Marlin_plonk_bindings.Pasta_fp_urs.Poly_comm.t array
        -> Pasta__Vesta_based_plonk.Verification_key.t
        -> 'a)
    -> Pasta__Vesta_based_plonk.Verification_key.t
    -> 'a

  val with_lagranges :
       (   Marlin_plonk_bindings.Pasta_fp_urs.Poly_comm.t array
           Core_kernel.Array.t
        -> Pasta__Vesta_based_plonk.Verification_key.t array
        -> 'a)
    -> Pasta__Vesta_based_plonk.Verification_key.t array
    -> 'a

  module Rounds_vector = Pasta__.Basic.Rounds.Step_vector
  module Rounds = Pasta__.Basic.Rounds.Step
  module Keypair = Pasta__Vesta_based_plonk.Keypair
  module Proof = Pasta__Vesta_based_plonk.Proof
  module Proving_key = Pasta__Vesta_based_plonk.Proving_key
  module Oracles = Pasta__Vesta_based_plonk.Oracles
  module Inner_curve = Zexe_backend.Pasta.Pallas
end

module Tock : sig
  module Field = Pasta__.Basic.Fq
  module Curve = Pasta__.Basic.Pallas
  module Bigint = Pasta__Pallas_based_plonk.Bigint

  val field_size : Pasta__Pallas_based_plonk.Bigint.R.t

  module Verification_key = Pasta__Pallas_based_plonk.Verification_key
  module R1CS_constraint_system =
    Pasta__Pallas_based_plonk.R1CS_constraint_system
  module Var = Zexe_backend_common.Var

  val lagrange : int -> Marlin_plonk_bindings.Pasta_fq_urs.Poly_comm.t array

  val with_lagrange :
       (   Marlin_plonk_bindings.Pasta_fq_urs.Poly_comm.t array
        -> Pasta__Pallas_based_plonk.Verification_key.t
        -> 'a)
    -> Pasta__Pallas_based_plonk.Verification_key.t
    -> 'a

  val with_lagranges :
       (   Marlin_plonk_bindings.Pasta_fq_urs.Poly_comm.t array
           Core_kernel.Array.t
        -> Pasta__Pallas_based_plonk.Verification_key.t array
        -> 'a)
    -> Pasta__Pallas_based_plonk.Verification_key.t array
    -> 'a

  module Rounds_vector = Pasta__.Basic.Rounds.Wrap_vector
  module Rounds = Pasta__.Basic.Rounds.Wrap
  module Keypair = Pasta__Pallas_based_plonk.Keypair
  module Proof = Pasta__Pallas_based_plonk.Proof
  module Proving_key = Pasta__Pallas_based_plonk.Proving_key
  module Oracles = Pasta__Pallas_based_plonk.Oracles
  module Inner_curve = Zexe_backend.Pasta.Vesta
end
