(* This file is generated automatically with ocaml_gen. *)

module Foundations = struct
  module BigInt256 = struct
    type nonrec t

    external of_numeral : string -> int -> int -> t
      = "caml_bigint_256_of_numeral"

    external of_decimal_string : string -> t
      = "caml_bigint_256_of_decimal_string"

    external num_limbs : unit -> int = "caml_bigint_256_num_limbs"

    external bytes_per_limb : unit -> int = "caml_bigint_256_bytes_per_limb"

    external div : t -> t -> t = "caml_bigint_256_div"

    external compare : t -> t -> int = "caml_bigint_256_compare"

    external print : t -> unit = "caml_bigint_256_print"

    external to_string : t -> string = "caml_bigint_256_to_string"

    external test_bit : t -> int -> bool = "caml_bigint_256_test_bit"

    external to_bytes : t -> bytes = "caml_bigint_256_to_bytes"

    external of_bytes : bytes -> t = "caml_bigint_256_of_bytes"

    external deep_copy : t -> t = "caml_bigint_256_deep_copy"
  end

  module Fp = struct
    type nonrec t

    external size_in_bits : unit -> int = "caml_pasta_fp_size_in_bits"

    external size : unit -> BigInt256.t = "caml_pasta_fp_size"

    external add : t -> t -> t = "caml_pasta_fp_add"

    external sub : t -> t -> t = "caml_pasta_fp_sub"

    external negate : t -> t = "caml_pasta_fp_negate"

    external mul : t -> t -> t = "caml_pasta_fp_mul"

    external div : t -> t -> t = "caml_pasta_fp_div"

    external inv : t -> t option = "caml_pasta_fp_inv"

    external square : t -> t = "caml_pasta_fp_square"

    external is_square : t -> bool = "caml_pasta_fp_is_square"

    external sqrt : t -> t option = "caml_pasta_fp_sqrt"

    external of_int : int -> t = "caml_pasta_fp_of_int"

    external to_string : t -> string = "caml_pasta_fp_to_string"

    external of_string : string -> t = "caml_pasta_fp_of_string"

    external print : t -> unit = "caml_pasta_fp_print"

    external copy : t -> t -> unit = "caml_pasta_fp_copy"

    external mut_add : t -> t -> unit = "caml_pasta_fp_mut_add"

    external mut_sub : t -> t -> unit = "caml_pasta_fp_mut_sub"

    external mut_mul : t -> t -> unit = "caml_pasta_fp_mut_mul"

    external mut_square : t -> unit = "caml_pasta_fp_mut_square"

    external compare : t -> t -> int = "caml_pasta_fp_compare"

    external equal : t -> t -> bool = "caml_pasta_fp_equal"

    external random : unit -> t = "caml_pasta_fp_random"

    external rng : int -> t = "caml_pasta_fp_rng"

    external to_bigint : t -> BigInt256.t = "caml_pasta_fp_to_bigint"

    external of_bigint : BigInt256.t -> t = "caml_pasta_fp_of_bigint"

    external two_adic_root_of_unity : unit -> t
      = "caml_pasta_fp_two_adic_root_of_unity"

    external domain_generator : int -> t = "caml_pasta_fp_domain_generator"

    external to_bytes : t -> bytes = "caml_pasta_fp_to_bytes"

    external of_bytes : bytes -> t = "caml_pasta_fp_of_bytes"

    external deep_copy : t -> t = "caml_pasta_fp_deep_copy"
  end

  module Fq = struct
    type nonrec t

    external size_in_bits : unit -> int = "caml_pasta_fq_size_in_bits"

    external size : unit -> BigInt256.t = "caml_pasta_fq_size"

    external add : t -> t -> t = "caml_pasta_fq_add"

    external sub : t -> t -> t = "caml_pasta_fq_sub"

    external negate : t -> t = "caml_pasta_fq_negate"

    external mul : t -> t -> t = "caml_pasta_fq_mul"

    external div : t -> t -> t = "caml_pasta_fq_div"

    external inv : t -> t option = "caml_pasta_fq_inv"

    external square : t -> t = "caml_pasta_fq_square"

    external is_square : t -> bool = "caml_pasta_fq_is_square"

    external sqrt : t -> t option = "caml_pasta_fq_sqrt"

    external of_int : int -> t = "caml_pasta_fq_of_int"

    external to_string : t -> string = "caml_pasta_fq_to_string"

    external of_string : string -> t = "caml_pasta_fq_of_string"

    external print : t -> unit = "caml_pasta_fq_print"

    external copy : t -> t -> unit = "caml_pasta_fq_copy"

    external mut_add : t -> t -> unit = "caml_pasta_fq_mut_add"

    external mut_sub : t -> t -> unit = "caml_pasta_fq_mut_sub"

    external mut_mul : t -> t -> unit = "caml_pasta_fq_mut_mul"

    external mut_square : t -> unit = "caml_pasta_fq_mut_square"

    external compare : t -> t -> int = "caml_pasta_fq_compare"

    external equal : t -> t -> bool = "caml_pasta_fq_equal"

    external random : unit -> t = "caml_pasta_fq_random"

    external rng : int -> t = "caml_pasta_fq_rng"

    external to_bigint : t -> BigInt256.t = "caml_pasta_fq_to_bigint"

    external of_bigint : BigInt256.t -> t = "caml_pasta_fq_of_bigint"

    external two_adic_root_of_unity : unit -> t
      = "caml_pasta_fq_two_adic_root_of_unity"

    external domain_generator : int -> t = "caml_pasta_fq_domain_generator"

    external to_bytes : t -> bytes = "caml_pasta_fq_to_bytes"

    external of_bytes : bytes -> t = "caml_pasta_fq_of_bytes"

    external deep_copy : t -> t = "caml_pasta_fq_deep_copy"
  end

  type nonrec 'F or_infinity = Infinity | Finite of ('F * 'F)
end

module FieldVectors = struct
  module Fp = struct
    type nonrec t

    type nonrec elt = Foundations.Fp.t

    external create : unit -> t = "caml_fp_vector_create"

    external length : t -> int = "caml_fp_vector_length"

    external emplace_back : t -> Foundations.Fp.t -> unit
      = "caml_fp_vector_emplace_back"

    external get : t -> int -> Foundations.Fp.t = "caml_fp_vector_get"

    external set : t -> int -> Foundations.Fp.t -> unit = "caml_fp_vector_set"
  end

  module Fq = struct
    type nonrec t

    type nonrec elt = Foundations.Fq.t

    external create : unit -> t = "caml_fq_vector_create"

    external length : t -> int = "caml_fq_vector_length"

    external emplace_back : t -> Foundations.Fq.t -> unit
      = "caml_fq_vector_emplace_back"

    external get : t -> int -> Foundations.Fq.t = "caml_fq_vector_get"

    external set : t -> int -> Foundations.Fq.t -> unit = "caml_fq_vector_set"
  end
end

module Vesta = struct
  module BaseField = struct
    type nonrec t = Foundations.Fq.t
  end

  module ScalarField = struct
    type nonrec t = Foundations.Fp.t
  end

  module Affine = struct
    type nonrec t = Foundations.Fq.t Foundations.or_infinity
  end

  type nonrec t

  external one : unit -> t = "caml_vesta_one"

  external add : t -> t -> t = "caml_vesta_add"

  external sub : t -> t -> t = "caml_vesta_sub"

  external negate : t -> t = "caml_vesta_negate"

  external double : t -> t = "caml_vesta_double"

  external scale : t -> Foundations.Fp.t -> t = "caml_vesta_scale"

  external random : unit -> t = "caml_vesta_random"

  external rng : int -> t = "caml_vesta_rng"

  external endo_base : unit -> Foundations.Fq.t = "caml_vesta_endo_base"

  external endo_scalar : unit -> Foundations.Fp.t = "caml_vesta_endo_scalar"

  external to_affine : t -> Foundations.Fq.t Foundations.or_infinity
    = "caml_vesta_to_affine"

  external of_affine : Foundations.Fq.t Foundations.or_infinity -> t
    = "caml_vesta_of_affine"

  external of_affine_coordinates : Foundations.Fq.t -> Foundations.Fq.t -> t
    = "caml_vesta_of_affine_coordinates"

  external deep_copy :
       Foundations.Fq.t Foundations.or_infinity
    -> Foundations.Fq.t Foundations.or_infinity = "caml_vesta_affine_deep_copy"
end

module Pallas = struct
  module BaseField = struct
    type nonrec t = Foundations.Fp.t
  end

  module ScalarField = struct
    type nonrec t = Foundations.Fq.t
  end

  module Affine = struct
    type nonrec t = Foundations.Fp.t Foundations.or_infinity
  end

  type nonrec t

  external one : unit -> t = "caml_pallas_one"

  external add : t -> t -> t = "caml_pallas_add"

  external sub : t -> t -> t = "caml_pallas_sub"

  external negate : t -> t = "caml_pallas_negate"

  external double : t -> t = "caml_pallas_double"

  external scale : t -> Foundations.Fq.t -> t = "caml_pallas_scale"

  external random : unit -> t = "caml_pallas_random"

  external rng : int -> t = "caml_pallas_rng"

  external endo_base : unit -> Foundations.Fp.t = "caml_pallas_endo_base"

  external endo_scalar : unit -> Foundations.Fq.t = "caml_pallas_endo_scalar"

  external to_affine : t -> Foundations.Fp.t Foundations.or_infinity
    = "caml_pallas_to_affine"

  external of_affine : Foundations.Fp.t Foundations.or_infinity -> t
    = "caml_pallas_of_affine"

  external of_affine_coordinates : Foundations.Fp.t -> Foundations.Fp.t -> t
    = "caml_pallas_of_affine_coordinates"

  external deep_copy :
       Foundations.Fp.t Foundations.or_infinity
    -> Foundations.Fp.t Foundations.or_infinity = "caml_pallas_affine_deep_copy"
end

module Protocol = struct
  type nonrec 'CamlF scalar_challenge = { inner : 'CamlF } [@@boxed]

  type nonrec 'CamlF random_oracles =
    { joint_combiner : 'CamlF scalar_challenge * 'CamlF
    ; beta : 'CamlF
    ; gamma : 'CamlF
    ; alpha_chal : 'CamlF scalar_challenge
    ; alpha : 'CamlF
    ; zeta : 'CamlF
    ; v : 'CamlF
    ; u : 'CamlF
    ; zeta_chal : 'CamlF scalar_challenge
    ; v_chal : 'CamlF scalar_challenge
    ; u_chal : 'CamlF scalar_challenge
    }

  type nonrec 'CamlF lookup_evaluations =
    { sorted : 'CamlF array array; aggreg : 'CamlF array; table : 'CamlF array }

  type nonrec 'CamlF proof_evaluations =
    { w :
        'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
    ; z : 'CamlF array
    ; s :
        'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
        * 'CamlF array
    ; generic_selector : 'CamlF array
    ; poseidon_selector : 'CamlF array
    }

  type nonrec 'CamlG poly_comm =
    { unshifted : 'CamlG array; shifted : 'CamlG option }

  type nonrec ('G, 'F) opening_proof =
    { lr : ('G * 'G) array; delta : 'G; z1 : 'F; z2 : 'F; sg : 'G }

  type nonrec 'CamlG prover_commitments =
    { w_comm :
        'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
        * 'CamlG poly_comm
    ; z_comm : 'CamlG poly_comm
    ; t_comm : 'CamlG poly_comm
    }

  type nonrec ('CamlG, 'CamlF) prover_proof =
    { commitments : 'CamlG prover_commitments
    ; proof : ('CamlG, 'CamlF) opening_proof
    ; evals : 'CamlF proof_evaluations * 'CamlF proof_evaluations
    ; ft_eval1 : 'CamlF
    ; public : 'CamlF array
    ; prev_challenges : ('CamlF array * 'CamlG poly_comm) array
    }

  type nonrec wire = { row : int; col : int }

  type nonrec gate_type =
    | Zero
    | Generic
    | Poseidon
    | CompleteAdd
    | VarBaseMul
    | EndoMul
    | EndoMulScalar
    | ChaCha0
    | ChaCha1
    | ChaCha2
    | ChaChaFinal

  type nonrec 'F circuit_gate =
    { typ : gate_type
    ; wires : wire * wire * wire * wire * wire * wire * wire
    ; coeffs : 'F array
    }

  type nonrec curr_or_next = Curr | Next

  type nonrec 'F oracles =
    { o : 'F random_oracles
    ; p_eval : 'F * 'F
    ; opening_prechallenges : 'F array
    ; digest_before_evaluations : 'F
    }

  module Gates = struct
    module Vector = struct
      module Fp = struct
        type nonrec t

        type nonrec elt = Foundations.Fp.t circuit_gate

        external create : unit -> t = "caml_pasta_fp_plonk_gate_vector_create"

        external add : t -> Foundations.Fp.t circuit_gate -> unit
          = "caml_pasta_fp_plonk_gate_vector_add"

        external get : t -> int -> Foundations.Fp.t circuit_gate
          = "caml_pasta_fp_plonk_gate_vector_get"

        external wrap : t -> wire -> wire -> unit
          = "caml_pasta_fp_plonk_gate_vector_wrap"

        external digest : t -> bytes = "caml_pasta_fp_plonk_gate_vector_digest"
      end

      module Fq = struct
        type nonrec t

        type nonrec elt = Foundations.Fq.t circuit_gate

        external create : unit -> t = "caml_pasta_fq_plonk_gate_vector_create"

        external add : t -> Foundations.Fq.t circuit_gate -> unit
          = "caml_pasta_fq_plonk_gate_vector_add"

        external get : t -> int -> Foundations.Fq.t circuit_gate
          = "caml_pasta_fq_plonk_gate_vector_get"

        external wrap : t -> wire -> wire -> unit
          = "caml_pasta_fq_plonk_gate_vector_wrap"

        external digest : t -> bytes = "caml_pasta_fq_plonk_gate_vector_digest"
      end
    end
  end

  module SRS = struct
    module Fp = struct
      type nonrec t

      module Poly_comm = struct
        type nonrec t = Foundations.Fp.t Foundations.or_infinity poly_comm
      end

      external create : int -> t = "caml_fp_srs_create"

      external write : bool option -> t -> string -> unit = "caml_fp_srs_write"

      external read : int option -> string -> t option = "caml_fp_srs_read"

      external lagrange_commitment :
        t -> int -> int -> Foundations.Fq.t Foundations.or_infinity poly_comm
        = "caml_fp_srs_lagrange_commitment"

      external commit_evaluations :
           t
        -> int
        -> Foundations.Fp.t array
        -> Foundations.Fq.t Foundations.or_infinity poly_comm
        = "caml_fp_srs_commit_evaluations"

      external b_poly_commitment :
           t
        -> Foundations.Fp.t array
        -> Foundations.Fq.t Foundations.or_infinity poly_comm
        = "caml_fp_srs_b_poly_commitment"

      external batch_accumulator_check :
           t
        -> Foundations.Fq.t Foundations.or_infinity array
        -> Foundations.Fp.t array
        -> bool = "caml_fp_srs_batch_accumulator_check"

      external urs_h : t -> Foundations.Fq.t Foundations.or_infinity
        = "caml_fp_srs_h"
    end

    module Fq = struct
      type nonrec t

      external create : int -> t = "caml_fq_srs_create"

      external write : bool option -> t -> string -> unit = "caml_fq_srs_write"

      external read : int option -> string -> t option = "caml_fq_srs_read"

      external lagrange_commitment :
        t -> int -> int -> Foundations.Fp.t Foundations.or_infinity poly_comm
        = "caml_fq_srs_lagrange_commitment"

      external commit_evaluations :
           t
        -> int
        -> Foundations.Fq.t array
        -> Foundations.Fp.t Foundations.or_infinity poly_comm
        = "caml_fq_srs_commit_evaluations"

      external b_poly_commitment :
           t
        -> Foundations.Fq.t array
        -> Foundations.Fp.t Foundations.or_infinity poly_comm
        = "caml_fq_srs_b_poly_commitment"

      external batch_accumulator_check :
           t
        -> Foundations.Fp.t Foundations.or_infinity array
        -> Foundations.Fq.t array
        -> bool = "caml_fq_srs_batch_accumulator_check"

      external urs_h : t -> Foundations.Fp.t Foundations.or_infinity
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
    module Lookup = struct
      type nonrec lookups_used = Single | Joint

      type nonrec 'PolyComm t =
        { lookup_used : lookups_used
        ; lookup_tables : 'PolyComm array array
        ; lookup_selectors : 'PolyComm array
        }
    end

    type nonrec 'Fr domain = { log_size_of_group : int; group_gen : 'Fr }

    type nonrec 'PolyComm verification_evals =
      { sigma_comm : 'PolyComm array
      ; coefficients_comm : 'PolyComm array
      ; generic_comm : 'PolyComm
      ; psm_comm : 'PolyComm
      ; complete_add_comm : 'PolyComm
      ; mul_comm : 'PolyComm
      ; emul_comm : 'PolyComm
      ; endomul_scalar_comm : 'PolyComm
      ; chacha_comm : 'PolyComm array option
      }

    type nonrec ('Fr, 'SRS, 'PolyComm) verifier_index =
      { domain : 'Fr domain
      ; max_poly_size : int
      ; max_quot_size : int
      ; srs : 'SRS
      ; evals : 'PolyComm verification_evals
      ; shifts : 'Fr array
      ; lookup_index : 'PolyComm Lookup.t option
      }

    module Fp = struct
      type nonrec t =
        ( Foundations.Fp.t
        , SRS.Fp.t
        , Foundations.Fq.t Foundations.or_infinity poly_comm )
        verifier_index

      external create :
           Index.Fp.t
        -> ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fp_plonk_verifier_index_create"

      external read :
           int option
        -> SRS.Fp.t
        -> string
        -> ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fp_plonk_verifier_index_read"

      external write :
           bool option
        -> ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           verifier_index
        -> string
        -> unit = "caml_pasta_fp_plonk_verifier_index_write"

      external shifts : int -> Foundations.Fp.t array
        = "caml_pasta_fp_plonk_verifier_index_shifts"

      external dummy :
           unit
        -> ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fp_plonk_verifier_index_dummy"

      external deep_copy :
           ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           verifier_index
        -> ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fp_plonk_verifier_index_deep_copy"
    end

    module Fq = struct
      type nonrec t =
        ( Foundations.Fq.t
        , SRS.Fq.t
        , Foundations.Fp.t Foundations.or_infinity poly_comm )
        verifier_index

      external create :
           Index.Fq.t
        -> ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fq_plonk_verifier_index_create"

      external read :
           int option
        -> SRS.Fq.t
        -> string
        -> ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fq_plonk_verifier_index_read"

      external write :
           bool option
        -> ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           verifier_index
        -> string
        -> unit = "caml_pasta_fq_plonk_verifier_index_write"

      external shifts : int -> Foundations.Fq.t array
        = "caml_pasta_fq_plonk_verifier_index_shifts"

      external dummy :
           unit
        -> ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fq_plonk_verifier_index_dummy"

      external deep_copy :
           ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           verifier_index
        -> ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           verifier_index = "caml_pasta_fq_plonk_verifier_index_deep_copy"
    end
  end

  module Oracles = struct
    module Fp = struct
      type nonrec t = Foundations.Fp.t oracles

      external create :
           Foundations.Fq.t Foundations.or_infinity poly_comm array
        -> ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           VerifierIndex.verifier_index
        -> ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof
        -> Foundations.Fp.t oracles = "fp_oracles_create"

      external dummy : unit -> Foundations.Fp.t random_oracles
        = "fp_oracles_dummy"

      external deep_copy :
        Foundations.Fp.t random_oracles -> Foundations.Fp.t random_oracles
        = "fp_oracles_deep_copy"
    end

    module Fq = struct
      type nonrec t = Foundations.Fq.t oracles

      external create :
           Foundations.Fp.t Foundations.or_infinity poly_comm array
        -> ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           VerifierIndex.verifier_index
        -> ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof
        -> Foundations.Fq.t oracles = "fq_oracles_create"

      external dummy : unit -> Foundations.Fq.t random_oracles
        = "fq_oracles_dummy"

      external deep_copy :
        Foundations.Fq.t random_oracles -> Foundations.Fq.t random_oracles
        = "fq_oracles_deep_copy"
    end
  end

  module Proof = struct
    module Fp = struct
      external create :
           Index.Fp.t
        -> FieldVectors.Fp.t array
        -> Foundations.Fp.t array
        -> Foundations.Fq.t Foundations.or_infinity array
        -> ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof = "caml_pasta_fp_plonk_proof_create"

      external verify :
           ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           VerifierIndex.verifier_index
        -> ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof
        -> bool = "caml_pasta_fp_plonk_proof_verify"

      external batch_verify :
           ( Foundations.Fp.t
           , SRS.Fp.t
           , Foundations.Fq.t Foundations.or_infinity poly_comm )
           VerifierIndex.verifier_index
           array
        -> ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof
           array
        -> bool = "caml_pasta_fp_plonk_proof_batch_verify"

      external dummy :
           unit
        -> ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof = "caml_pasta_fp_plonk_proof_dummy"

      external deep_copy :
           ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof
        -> ( Foundations.Fq.t Foundations.or_infinity
           , Foundations.Fp.t )
           prover_proof = "caml_pasta_fp_plonk_proof_deep_copy"
    end

    module Fq = struct
      external create :
           Index.Fq.t
        -> FieldVectors.Fq.t array
        -> Foundations.Fq.t array
        -> Foundations.Fp.t Foundations.or_infinity array
        -> ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof = "caml_pasta_fq_plonk_proof_create"

      external verify :
           ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           VerifierIndex.verifier_index
        -> ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof
        -> bool = "caml_pasta_fq_plonk_proof_verify"

      external batch_verify :
           ( Foundations.Fq.t
           , SRS.Fq.t
           , Foundations.Fp.t Foundations.or_infinity poly_comm )
           VerifierIndex.verifier_index
           array
        -> ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof
           array
        -> bool = "caml_pasta_fq_plonk_proof_batch_verify"

      external dummy :
           unit
        -> ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof = "caml_pasta_fq_plonk_proof_dummy"

      external deep_copy :
           ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof
        -> ( Foundations.Fp.t Foundations.or_infinity
           , Foundations.Fq.t )
           prover_proof = "caml_pasta_fq_plonk_proof_deep_copy"
    end
  end
end
