open Zexe_backend_common
open Basic_plonk
module T = Snarky_bn382.Tweedle
module Field = Fp
module B = T.Dee_plonk.Plonk
module Curve = Dee

module Bigint = struct
  module R = struct
    include Field.Bigint

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end
end

let field_size : Bigint.R.t = Field.size

module Gates = struct
  include T.Dee_plonk.Plonk.Gate_vector

  let create () =
    let t = create () in
    Caml.Gc.finalise delete t ; t
end

module R1CS_constraint_system = Plonk_constraint_system.Make (Field) (Gates)
module Var = Var

module Verification_key = struct
  type t = B.Field_verifier_index.t

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Proof = Dlog_plonk_based_proof.Make (struct
  module Scalar_field = Field
  module Backend = B.Field_proof
  module Verifier_index = B.Field_verifier_index
  module Index = B.Field_index
  module Evaluations_backend = B.Field_proof.Evaluations
  module Opening_proof_backend = B.Field_opening_proof
  module Poly_comm = Fp_poly_comm
  module Curve = Curve
end)

module Proving_key = struct
  type t = B.Field_index.t

  include Core_kernel.Binable.Of_binable
            (Core_kernel.Unit)
            (struct
              type nonrec t = t

              let to_binable _ = ()

              let of_binable () = failwith "TODO"
            end)

  let is_initialized _ = `Yes

  let set_constraint_system _ _ = ()

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Rounds = Rounds.Wrap

module Oracles = Dlog_plonk_based_oracles.Make (struct
  module Verifier_index = B.Field_verifier_index
  module Field = Field
  module Proof = Proof
  module Backend = B.Field_oracles
end)

module Keypair = Dlog_plonk_based_keypair.Make (struct
  let name = "tweedledee"

  module Rounds = Rounds
  module Urs = B.Field_urs
  module Index = B.Field_index
  module Curve = Curve
  module Poly_comm = Fp_poly_comm
  module Verifier_index = B.Field_verifier_index
  module Gate_vector = B.Gate_vector
end)
