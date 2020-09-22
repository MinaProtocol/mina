open Zexe_backend_common
open Basic
module T = Snarky_bn382.Tweedle
module Field = Fq
module B = T.Dum.Plonk
module Curve = Dum

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

module R1CS_constraint_system = struct
  type t = B.Constraint_system.t Zexe_backend_common.Plonk_r1cs_constraint_system.t

  let underlying _ : B.Constraint_system.t = failwith __LOC__

  let create () = ref 0
  let to_json _ = `List []

  let get_auxiliary_input_size (_ : t) = 0
  let get_primary_input_size (_ : t) = 0
  let set_auxiliary_input_size (_ : t) _x = ()
  let set_primary_input_size (_ : t) _x = ()
  let digest _ = Core_kernel.Md5.digest_string ""
  let finalize = ignore
  let add_constraint ?label:_ (t : t) _c = incr t
end

module Var = Var

let lagrange =
  let open Core_kernel in
  let f = 
    Memo.general
      ~hashable:Int.hashable
      (fun domain_log2 ->
        let open B.Field_poly_comm in
        let v = Vector.create () in
        Array.iter Precomputed.Lagrange_precomputations.(dum.(index_of_domain_log2 domain_log2)) ~f:(fun g ->
            Vector.emplace_back v
            (Fq_poly_comm.to_backend (`Without_degree_bound g) )
          ) ;
        v )
  in 
  fun x -> f (Unsigned.UInt32.to_int x)

let with_lagrange f = 
  fun vk -> f (lagrange (B.Field_verifier_index.domain_log2 vk)) vk

module Proof = Plonk_dlog_proof.Make (struct
  module Scalar_field = Field
  module Backend = struct
    include B.Field_proof
    let verify = with_lagrange verify
    let batch_verify = with_lagrange batch_verify
  end 
  module Verifier_index = Verification_key
  module Index = B.Field_index
  module Evaluations_backend = B.Field_proof.Evaluations
  module Opening_proof_backend = B.Field_opening_proof
  module Poly_comm = Fq_poly_comm
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

module Rounds = Rounds.Step

module Keypair = Plonk_dlog_keypair.Make (struct
  let name = "tweedledum"

  module Rounds = Rounds
  module Urs = B.Field_urs
  module Index = struct
    include B.Field_index
    let create sys = create (R1CS_constraint_system.underlying sys)
  end 
  module Curve = Curve
  module Poly_comm = Fq_poly_comm
  module Scalar_field = Field
  module Verifier_index = B.Field_verifier_index
  module Gate_vector = B.Gate_vector
  module Constraint_system = R1CS_constraint_system
end)

module Oracles = Plonk_dlog_oracles.Make (struct
  module Verifier_index = Verification_key
  module Field = Field
  module Proof = Proof
  module Backend = struct
    open Core_kernel
    include B.Field_oracles
    let create = with_lagrange create
  end 
end)
