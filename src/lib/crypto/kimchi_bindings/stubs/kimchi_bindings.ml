(* This file is generated automatically with ocaml_gen. *)

module FieldVectors = struct
  module Fp = struct
    type nonrec t

    type nonrec elt = Pasta_bindings.Fp.t

    external create : unit -> t = "caml_fp_vector_create"

    external length : t -> int = "caml_fp_vector_length"

    external emplace_back : t -> Pasta_bindings.Fp.t -> unit
      = "caml_fp_vector_emplace_back"

    external get : t -> int -> Pasta_bindings.Fp.t = "caml_fp_vector_get"

    external set : t -> int -> Pasta_bindings.Fp.t -> unit
      = "caml_fp_vector_set"
  end

  module Fq = struct
    type nonrec t

    type nonrec elt = Pasta_bindings.Fq.t

    external create : unit -> t = "caml_fq_vector_create"

    external length : t -> int = "caml_fq_vector_length"

    external emplace_back : t -> Pasta_bindings.Fq.t -> unit
      = "caml_fq_vector_emplace_back"

    external get : t -> int -> Pasta_bindings.Fq.t = "caml_fq_vector_get"

    external set : t -> int -> Pasta_bindings.Fq.t -> unit
      = "caml_fq_vector_set"
  end
end

module Protocol = struct
  module Gates = struct
    module Vector = struct
      module Fp = struct
        type nonrec t

        type nonrec elt = Pasta_bindings.Fp.t Kimchi_types.circuit_gate

        external create : unit -> t = "caml_pasta_fp_plonk_gate_vector_create"

        external add :
          t -> Pasta_bindings.Fp.t Kimchi_types.circuit_gate -> unit
          = "caml_pasta_fp_plonk_gate_vector_add"

        external get : t -> int -> Pasta_bindings.Fp.t Kimchi_types.circuit_gate
          = "caml_pasta_fp_plonk_gate_vector_get"

        external wrap : t -> Kimchi_types.wire -> Kimchi_types.wire -> unit
          = "caml_pasta_fp_plonk_gate_vector_wrap"

        external digest : t -> bytes = "caml_pasta_fp_plonk_gate_vector_digest"
      end

      module Fq = struct
        type nonrec t

        type nonrec elt = Pasta_bindings.Fq.t Kimchi_types.circuit_gate

        external create : unit -> t = "caml_pasta_fq_plonk_gate_vector_create"

        external add :
          t -> Pasta_bindings.Fq.t Kimchi_types.circuit_gate -> unit
          = "caml_pasta_fq_plonk_gate_vector_add"

        external get : t -> int -> Pasta_bindings.Fq.t Kimchi_types.circuit_gate
          = "caml_pasta_fq_plonk_gate_vector_get"

        external wrap : t -> Kimchi_types.wire -> Kimchi_types.wire -> unit
          = "caml_pasta_fq_plonk_gate_vector_wrap"

        external digest : t -> bytes = "caml_pasta_fq_plonk_gate_vector_digest"
      end
    end
  end

  module SRS = struct
    module Fp = struct
      type nonrec t

      module Poly_comm = struct
        type nonrec t =
          Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
      end

      external create : int -> t = "caml_fp_srs_create"

      external write : bool option -> t -> string -> unit = "caml_fp_srs_write"

      external read : int option -> string -> t option = "caml_fp_srs_read"

      external lagrange_commitment :
           t
        -> int
        -> int
        -> Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        = "caml_fp_srs_lagrange_commitment"

      external add_lagrange_basis : t -> int -> unit
        = "caml_fp_srs_add_lagrange_basis"

      external commit_evaluations :
           t
        -> int
        -> Pasta_bindings.Fp.t array
        -> Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        = "caml_fp_srs_commit_evaluations"

      external b_poly_commitment :
           t
        -> Pasta_bindings.Fp.t array
        -> Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        = "caml_fp_srs_b_poly_commitment"

      external batch_accumulator_check :
           t
        -> Pasta_bindings.Fq.t Kimchi_types.or_infinity array
        -> Pasta_bindings.Fp.t array
        -> bool = "caml_fp_srs_batch_accumulator_check"

      external urs_h : t -> Pasta_bindings.Fq.t Kimchi_types.or_infinity
        = "caml_fp_srs_h"
    end

    module Fq = struct
      type nonrec t

      external create : int -> t = "caml_fq_srs_create"

      external write : bool option -> t -> string -> unit = "caml_fq_srs_write"

      external read : int option -> string -> t option = "caml_fq_srs_read"

      external lagrange_commitment :
           t
        -> int
        -> int
        -> Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        = "caml_fq_srs_lagrange_commitment"

      external add_lagrange_basis : t -> int -> unit
        = "caml_fq_srs_add_lagrange_basis"

      external commit_evaluations :
           t
        -> int
        -> Pasta_bindings.Fq.t array
        -> Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        = "caml_fq_srs_commit_evaluations"

      external b_poly_commitment :
           t
        -> Pasta_bindings.Fq.t array
        -> Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        = "caml_fq_srs_b_poly_commitment"

      external batch_accumulator_check :
           t
        -> Pasta_bindings.Fp.t Kimchi_types.or_infinity array
        -> Pasta_bindings.Fq.t array
        -> bool = "caml_fq_srs_batch_accumulator_check"

      external urs_h : t -> Pasta_bindings.Fp.t Kimchi_types.or_infinity
        = "caml_fq_srs_h"
    end
  end

  module Index = struct
    module Fp = struct
      type nonrec t

      external create : Gates.Vector.Fp.t -> int -> SRS.Fp.t -> t
        = "caml_pasta_fp_plonk_index_create"

      external max_degree : t -> int = "caml_pasta_fp_plonk_index_max_degree"

      external public_inputs : t -> int
        = "caml_pasta_fp_plonk_index_public_inputs"

      external domain_d1_size : t -> int
        = "caml_pasta_fp_plonk_index_domain_d1_size"

      external domain_d4_size : t -> int
        = "caml_pasta_fp_plonk_index_domain_d4_size"

      external domain_d8_size : t -> int
        = "caml_pasta_fp_plonk_index_domain_d8_size"

      external read : int option -> SRS.Fp.t -> string -> t
        = "caml_pasta_fp_plonk_index_read"

      external write : bool option -> t -> string -> unit
        = "caml_pasta_fp_plonk_index_write"
    end

    module Fq = struct
      type nonrec t

      external create : Gates.Vector.Fq.t -> int -> SRS.Fq.t -> t
        = "caml_pasta_fq_plonk_index_create"

      external max_degree : t -> int = "caml_pasta_fq_plonk_index_max_degree"

      external public_inputs : t -> int
        = "caml_pasta_fq_plonk_index_public_inputs"

      external domain_d1_size : t -> int
        = "caml_pasta_fq_plonk_index_domain_d1_size"

      external domain_d4_size : t -> int
        = "caml_pasta_fq_plonk_index_domain_d4_size"

      external domain_d8_size : t -> int
        = "caml_pasta_fq_plonk_index_domain_d8_size"

      external read : int option -> SRS.Fq.t -> string -> t
        = "caml_pasta_fq_plonk_index_read"

      external write : bool option -> t -> string -> unit
        = "caml_pasta_fq_plonk_index_write"
    end
  end

  module VerifierIndex = struct
    module Fp = struct
      type nonrec t =
        ( Pasta_bindings.Fp.t
        , SRS.Fp.t
        , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        )
        Kimchi_types.VerifierIndex.verifier_index

      external create :
           Index.Fp.t
        -> ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fp_plonk_verifier_index_create"

      external read :
           int option
        -> SRS.Fp.t
        -> string
        -> ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fp_plonk_verifier_index_read"

      external write :
           bool option
        -> ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> string
        -> unit = "caml_pasta_fp_plonk_verifier_index_write"

      external shifts : int -> Pasta_bindings.Fp.t array
        = "caml_pasta_fp_plonk_verifier_index_shifts"

      external dummy :
           unit
        -> ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fp_plonk_verifier_index_dummy"

      external deep_copy :
           ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fp_plonk_verifier_index_deep_copy"
    end

    module Fq = struct
      type nonrec t =
        ( Pasta_bindings.Fq.t
        , SRS.Fq.t
        , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
        )
        Kimchi_types.VerifierIndex.verifier_index

      external create :
           Index.Fq.t
        -> ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fq_plonk_verifier_index_create"

      external read :
           int option
        -> SRS.Fq.t
        -> string
        -> ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fq_plonk_verifier_index_read"

      external write :
           bool option
        -> ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> string
        -> unit = "caml_pasta_fq_plonk_verifier_index_write"

      external shifts : int -> Pasta_bindings.Fq.t array
        = "caml_pasta_fq_plonk_verifier_index_shifts"

      external dummy :
           unit
        -> ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fq_plonk_verifier_index_dummy"

      external deep_copy :
           ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        = "caml_pasta_fq_plonk_verifier_index_deep_copy"
    end
  end

  module Oracles = struct
    module Fp = struct
      type nonrec t = Pasta_bindings.Fp.t Kimchi_types.oracles

      external create :
           Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           array
        -> ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof
        -> Pasta_bindings.Fp.t Kimchi_types.oracles = "fp_oracles_create"

      external dummy : unit -> Pasta_bindings.Fp.t Kimchi_types.random_oracles
        = "fp_oracles_dummy"

      external deep_copy :
           Pasta_bindings.Fp.t Kimchi_types.random_oracles
        -> Pasta_bindings.Fp.t Kimchi_types.random_oracles
        = "fp_oracles_deep_copy"
    end

    module Fq = struct
      type nonrec t = Pasta_bindings.Fq.t Kimchi_types.oracles

      external create :
           Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           array
        -> ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof
        -> Pasta_bindings.Fq.t Kimchi_types.oracles = "fq_oracles_create"

      external dummy : unit -> Pasta_bindings.Fq.t Kimchi_types.random_oracles
        = "fq_oracles_dummy"

      external deep_copy :
           Pasta_bindings.Fq.t Kimchi_types.random_oracles
        -> Pasta_bindings.Fq.t Kimchi_types.random_oracles
        = "fq_oracles_deep_copy"
    end
  end

  module Proof = struct
    module Fp = struct
      external create :
           Index.Fp.t
        -> FieldVectors.Fp.t array
        -> Pasta_bindings.Fp.t array
        -> Pasta_bindings.Fq.t Kimchi_types.or_infinity array
        -> ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof = "caml_pasta_fp_plonk_proof_create"

      external verify :
           ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof
        -> bool = "caml_pasta_fp_plonk_proof_verify"

      external batch_verify :
           ( Pasta_bindings.Fp.t
           , SRS.Fp.t
           , Pasta_bindings.Fq.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
           array
        -> ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof
           array
        -> bool = "caml_pasta_fp_plonk_proof_batch_verify"

      external dummy :
           unit
        -> ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof = "caml_pasta_fp_plonk_proof_dummy"

      external deep_copy :
           ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof
        -> ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
           , Pasta_bindings.Fp.t )
           Kimchi_types.prover_proof = "caml_pasta_fp_plonk_proof_deep_copy"
    end

    module Fq = struct
      external create :
           Index.Fq.t
        -> FieldVectors.Fq.t array
        -> Pasta_bindings.Fq.t array
        -> Pasta_bindings.Fp.t Kimchi_types.or_infinity array
        -> ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof = "caml_pasta_fq_plonk_proof_create"

      external verify :
           ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
        -> ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof
        -> bool = "caml_pasta_fq_plonk_proof_verify"

      external batch_verify :
           ( Pasta_bindings.Fq.t
           , SRS.Fq.t
           , Pasta_bindings.Fp.t Kimchi_types.or_infinity Kimchi_types.poly_comm
           )
           Kimchi_types.VerifierIndex.verifier_index
           array
        -> ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof
           array
        -> bool = "caml_pasta_fq_plonk_proof_batch_verify"

      external dummy :
           unit
        -> ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof = "caml_pasta_fq_plonk_proof_dummy"

      external deep_copy :
           ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof
        -> ( Pasta_bindings.Fp.t Kimchi_types.or_infinity
           , Pasta_bindings.Fq.t )
           Kimchi_types.prover_proof = "caml_pasta_fq_plonk_proof_deep_copy"
    end
  end
end
