open Core_kernel
open Kimchi_backend_common
open Kimchi_pasta_basic
module Field = Fq
module Curve = Pallas

module Bigint = struct
  include Field.Bigint

  let of_data _ = failwith __LOC__

  let to_field = Field.of_bigint

  let of_field = Field.to_bigint
end

let field_size : Bigint.t = Field.size

module Verification_key = struct
  type t =
    ( Pasta_bindings.Fq.t
    , Kimchi_bindings.Protocol.SRS.Fq.t
    , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm )
    Kimchi_types.VerifierIndex.verifier_index

  let to_string _ = failwith __LOC__

  let of_string _ = failwith __LOC__

  let shifts (t : t) : Field.t array = t.shifts
end

(* TODO: change name *)
module R1CS_constraint_system =
  Kimchi_pasta_constraint_system.Pallas_constraint_system

let lagrange srs domain_log2 : _ Kimchi_types.poly_comm array =
  let domain_size = Int.pow 2 domain_log2 in
  Array.init domain_size ~f:(fun i ->
      Kimchi_bindings.Protocol.SRS.Fq.lagrange_commitment srs domain_size i )

let with_lagrange f (vk : Verification_key.t) =
  f (lagrange vk.srs vk.domain.log_size_of_group) vk

let with_lagranges f (vks : Verification_key.t array) =
  let lgrs =
    Array.map vks ~f:(fun vk -> lagrange vk.srs vk.domain.log_size_of_group)
  in
  f lgrs vks

module Rounds_vector = Rounds.Wrap_vector
module Rounds = Rounds.Wrap

module Keypair = Dlog_plonk_based_keypair.Make (struct
  let name = "pallas"

  module Rounds = Rounds
  module Urs = Kimchi_bindings.Protocol.SRS.Fq
  module Index = Kimchi_bindings.Protocol.Index.Fq
  module Curve = Curve
  module Poly_comm = Fq_poly_comm
  module Scalar_field = Field
  module Verifier_index = Kimchi_bindings.Protocol.VerifierIndex.Fq
  module Gate_vector = Kimchi_bindings.Protocol.Gates.Vector.Fq
  module Constraint_system = R1CS_constraint_system
end)

module Proof = Plonk_dlog_proof.Make (struct
  let id = "pasta_pallas"

  module Scalar_field = Field
  module Base_field = Fp

  module Backend = struct
    type t =
      ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
      , Pasta_bindings.Fq.t )
      Kimchi_types.prover_proof

    type with_public_evals =
      ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
      , Pasta_bindings.Fq.t )
      Kimchi_types.proof_with_public

    include Kimchi_bindings.Protocol.Proof.Fq

    let batch_verify vks ts =
      Promise.run_in_thread (fun () -> batch_verify vks ts)

    let create_aux ~f:backend_create (pk : Keypair.t) ~primary ~auxiliary
        ~prev_chals ~prev_comms =
      (* external values contains [1, primary..., auxiliary ] *)
      let external_values i =
        let open Field.Vector in
        if i < length primary then get primary i
        else get auxiliary (i - length primary)
      in

      (* compute witness *)
      let computed_witness, runtime_tables =
        R1CS_constraint_system.compute_witness pk.cs external_values
      in
      let num_rows = Array.length computed_witness.(0) in

      (* convert to Rust vector *)
      let witness_cols =
        Array.init Kimchi_backend_common.Constants.columns ~f:(fun col ->
            let witness = Field.Vector.create () in
            for row = 0 to num_rows - 1 do
              Field.Vector.emplace_back witness computed_witness.(col).(row)
            done ;
            witness )
      in
      backend_create pk.index witness_cols runtime_tables prev_chals prev_comms

    let create_async (pk : Keypair.t) ~primary ~auxiliary ~prev_chals
        ~prev_comms =
      create_aux pk ~primary ~auxiliary ~prev_chals ~prev_comms
        ~f:(fun index witness runtime_tables prev_chals prev_sgs ->
          Promise.run_in_thread (fun () ->
              Kimchi_bindings.Protocol.Proof.Fq.create index witness
                runtime_tables prev_chals prev_sgs ) )

    let create (pk : Keypair.t) ~primary ~auxiliary ~prev_chals ~prev_comms =
      create_aux pk ~primary ~auxiliary ~prev_chals ~prev_comms
        ~f:Kimchi_bindings.Protocol.Proof.Fq.create
  end

  module Verifier_index = Kimchi_bindings.Protocol.VerifierIndex.Fq
  module Index = Keypair

  module Evaluations_backend = struct
    type t = Scalar_field.t Kimchi_types.proof_evaluations
  end

  module Opening_proof_backend = struct
    type t = (Curve.Affine.Backend.t, Scalar_field.t) Kimchi_types.opening_proof
  end

  module Poly_comm = Fq_poly_comm
  module Curve = Curve
end)

module Proving_key = struct
  type t = Keypair.t

  include
    Core_kernel.Binable.Of_binable
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
    include Kimchi_bindings.Protocol.Oracles.Fq

    let create = with_lagrange create

    let create_with_public_evals = with_lagrange create_with_public_evals
  end
end)
