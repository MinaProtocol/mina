open Zexe_backend_common
open Basic_plonk
module T = Snarky_bn382.Tweedle
module Field = Fq
module B = T.Dum_plonk.Plonk
module Curve = Dum

module Bigint = struct
  module R = struct
    include Field.Bigint

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end
end

let field_size : Bigint.R.t = Field.size

module Gates = struct
  include T.Dum_plonk.Plonk.Gate_vector

  let create () =
    let t = create () in
    Caml.Gc.finalise delete t ; t
end

module Params = struct let params =
  Sponge.Params.(map tweedle_q ~f:(fun x -> Field.of_bigint (Bigint256.of_decimal_string x))) end

module R1CS_constraint_system = Plonk_constraint_system.Make (Field) (Gates) (Params)
module Var = Var

module Verification_key = struct
  type t = B.Field_verifier_index.t

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Rounds = Rounds.Step

module Keypair = Dlog_plonk_based_keypair.Make (struct
  let name = "tweedledum"

  module Scalar_field = Field
  module Rounds = Rounds
  module Urs = B.Field_urs
  module Index = B.Field_index
  module Curve = Curve
  module Poly_comm = Fq_poly_comm
  module Verifier_index = B.Field_verifier_index
  module Gate_vector = B.Gate_vector
end)

module Proving_key = struct
  type t = Keypair.t

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

module Proof = Dlog_plonk_based_proof.Make (struct
  module Scalar_field = Field
  module Backend = struct
    include B.Field_proof
    let create (pk : Keypair.t) primary auxiliary prev_chals prev_comms =
      let external_values i =
        if i = 0 then Field.one
        else if i - 1 < Field.Vector.length primary
        then Field.Vector.get primary (i - 1)
        else Field.Vector.get auxiliary (i - 1 - Field.Vector.length primary)
      in
      let w = R1CS_constraint_system.compute_witness pk.cs external_values in
      let n = Unsigned.Size_t.to_int (B.Field_index.domain_d1_size pk.index) in
      let witness = Field.Vector.create() in

      Printf.printf "I: %d, I: %d, J: %d\n" n (Array.length w.(0)) (Array.length w); 

      for i = 0 to Array.length w.(0) - 1 do
        for j = 0 to n - 1 do
          Field.Vector.emplace_back witness (if j < (Array.length w) then w.(j).(i) else Field.zero)
        done;
      done;
      create pk.index (Field.Vector.create()) witness prev_chals prev_comms
  end
  module Verifier_index = B.Field_verifier_index
  module Index = Keypair
  module Evaluations_backend = B.Field_proof.Evaluations
  module Opening_proof_backend = B.Field_opening_proof
  module Poly_comm = Fq_poly_comm
  module Curve = Curve
end)

module Oracles = Dlog_plonk_based_oracles.Make (struct
  module Verifier_index = B.Field_verifier_index
  module Field = Field
  module Proof = Proof
  module Backend = B.Field_oracles
end)
