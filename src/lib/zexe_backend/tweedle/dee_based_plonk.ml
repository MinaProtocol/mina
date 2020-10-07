open Core
open Zexe_backend_common
open Basic
module T = Snarky_bn382.Tweedle
module Field = Fp
module B = T.Dee.Plonk
module Curve = Dee

module Bigint = struct
  module R = struct
    include Field.Bigint

    let to_field = Field.of_bigint

    let of_field = Field.to_bigint
  end
end

let field_size : Bigint.R.t = Field.size

module Verification_key = struct
  type t = B.Field_verifier_index.t

  let to_string _ = failwith __LOC__

  let of_string _ = failwith __LOC__
end

module R1CS_constraint_system =
  Plonk_constraint_system.Make (Field) (B.Gate_vector)
    (struct
      let params =
        Sponge.Params.(
          map tweedle_p ~f:(fun x ->
              Field.of_bigint (Bigint256.of_decimal_string x) ))
    end)

module Var = Var

let lagrange =
  let open Core_kernel in
  let f =
    Memo.general ~hashable:Int.hashable (fun domain_log2 ->
        let open B.Field_poly_comm in
        let v = Vector.create () in
        Array.iter
          Precomputed.Lagrange_precomputations.(
            dee.(index_of_domain_log2 domain_log2))
          ~f:(fun g ->
            Vector.emplace_back v
              (Fp_poly_comm.to_backend (`Without_degree_bound g)) ) ;
        v )
  in
  fun x -> f (Unsigned.UInt32.to_int x)

let with_lagrange f vk =
  f (lagrange (B.Field_verifier_index.domain_log2 vk)) vk

let with_lagranges f vks =
  let lgrs = B.Field_poly_comm.Vector.Vector.create () in
  for i = 0 to B.Field_verifier_index.Vector.length vks - 1 do
    B.Field_poly_comm.Vector.Vector.emplace_back lgrs
      (lagrange B.Field_verifier_index.(domain_log2 (Vector.get vks i)))
  done ;
  f lgrs vks

module Rounds = Rounds.Wrap

module Keypair = Dlog_plonk_based_keypair.Make (struct
  let name = "tweedledee"

  module Rounds = Rounds
  module Urs = B.Field_urs
  module Index = B.Field_index
  module Curve = Curve
  module Poly_comm = Fp_poly_comm
  module Scalar_field = Field
  module Verifier_index = B.Field_verifier_index
  module Gate_vector = B.Gate_vector
  module Constraint_system = R1CS_constraint_system
end)

module Proof = Plonk_dlog_proof.Make (struct
  module Scalar_field = Field

  module Backend = struct
    include B.Field_proof

    let verify = with_lagrange verify

    let batch_verify = with_lagranges batch_verify

    let create (pk : Keypair.t) primary auxiliary prev_chals prev_comms =
      let external_values i =
        let open Field.Vector in
        if i = 0 then Field.one
        else if i - 1 < length primary then get primary (i - 1)
        else get auxiliary (i - 1 - length primary)
      in
      let w = R1CS_constraint_system.compute_witness pk.cs external_values in
      let n = Unsigned.Size_t.to_int (B.Field_index.domain_d1_size pk.index) in
      let witness = Field.Vector.create () in
      for i = 0 to Array.length w.(0) - 1 do
        for j = 0 to n - 1 do
          let w = if j < Array.length w then w.(j).(i) else Field.zero in
          Field.Vector.emplace_back witness w;
          (*print_endline (Sexp.to_string ([%sexp_of: Field.t] w));*)
        done
      done ;
      create pk.index (Field.Vector.create ()) witness prev_chals prev_comms
  end

  module Verifier_index = B.Field_verifier_index
  module Index = Keypair
  module Evaluations_backend = B.Field_proof.Evaluations
  module Opening_proof_backend = B.Field_opening_proof
  module Poly_comm = Fp_poly_comm
  module Curve = Curve
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

module Oracles = Plonk_dlog_oracles.Make (struct
  module Verifier_index = Verification_key
  module Field = Field
  module Proof = Proof

  module Backend = struct
    include B.Field_oracles

    let create = with_lagrange create
  end
end)
