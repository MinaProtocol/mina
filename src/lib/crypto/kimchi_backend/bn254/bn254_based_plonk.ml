open Core_kernel
open Kimchi_backend_common
open Kimchi_bn254_basic
module Field = Bn254_fp
module Curve = Bn254_curve

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

module Rounds = Kimchi_pasta_basic.Rounds.Step

module Keypair = Dlog_plonk_based_keypair.Make (struct
  let name = "bn254"

  module Rounds = Rounds
  module Urs = Kimchi_bindings.Protocol.SRS.Bn254Fp
  module Index = Kimchi_bindings.Protocol.Index.Bn254Fp
  module Curve = Curve
  module Poly_comm = Fp_poly_comm
  module Scalar_field = Field
  module Verifier_index = Kimchi_bindings.Protocol.VerifierIndex.Bn254Fp
  module Gate_vector = Kimchi_bindings.Protocol.Gates.Vector.Bn254Fp
  module Constraint_system = R1CS_constraint_system
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

module Proof = struct
  include Kimchi_bindings.Protocol.Proof.Bn254Fp

  let create_aux ~f:create (pk : Keypair.t) primary auxiliary =
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
    create pk.index witness_cols runtime_tables

  let create (pk : Keypair.t) ~primary ~auxiliary =
    create_aux pk primary auxiliary ~f:create
end
