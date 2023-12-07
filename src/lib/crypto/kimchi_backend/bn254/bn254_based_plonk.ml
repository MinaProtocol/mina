open Core_kernel
open Kimchi_backend_common
open Kimchi_bn254_basic
module Field = Bn254Fp
module Curve = Bn254

module Bigint = struct
  include Field.Bigint

  let of_data _ = failwith __LOC__

  let to_field = Field.of_bigint

  let of_field = Field.to_bigint
end

let field_size : Bigint.t = Field.size

module Verification_key = struct
  type t =
    ( Bn254_bindings.Bn254Fp.t
    , Kimchi_bindings.Protocol.SRS.Bn254Fp.t
    , Bn254_bindings.Bn254Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm )
    Kimchi_types.VerifierIndex.verifier_index

  let to_string _ = failwith __LOC__

  let of_string _ = failwith __LOC__

  let shifts (t : t) = t.shifts
end

module R1CS_constraint_system =
  Kimchi_bn254_constraint_system.Bn254_constraint_system

module Keypair = Dlog_plonk_based_keypair.Make (struct
  let name = "bn254"

  module Rounds = Kimchi_pasta_basic.Rounds
  module Urs = Kimchi_bindings.Protocol.SRS.Bn254Fp
  module Index = Kimchi_bindings.Protocol.Index.Bn254Fp
  module Curve = Curve
  module Poly_comm = Fp_poly_comm
  module Scalar_field = Field
  module Verifier_index = Kimchi_bindings.Protocol.VerifierIndex.Bn254Fp
  module Gate_vector = Kimchi_bindings.Protocol.Gates.Vector.Bn254Fp
  module Constraint_system = R1CS_constraint_system
end)
