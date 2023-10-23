(* This file is generated automatically with ocaml_gen. *)
type nonrec 'f or_infinity = Infinity | Finite of ('f * 'f)

type nonrec 'caml_f scalar_challenge = { inner : 'caml_f } [@@boxed]

type nonrec 'caml_f random_oracles =
  { joint_combiner : ('caml_f scalar_challenge * 'caml_f) option
  ; beta : 'caml_f
  ; gamma : 'caml_f
  ; alpha_chal : 'caml_f scalar_challenge
  ; alpha : 'caml_f
  ; zeta : 'caml_f
  ; v : 'caml_f
  ; u : 'caml_f
  ; zeta_chal : 'caml_f scalar_challenge
  ; v_chal : 'caml_f scalar_challenge
  ; u_chal : 'caml_f scalar_challenge
  }

type nonrec 'evals point_evaluations = { zeta : 'evals; zeta_omega : 'evals }

type nonrec 'caml_f proof_evaluations =
  { w :
      'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
  ; z : 'caml_f array point_evaluations
  ; s :
      'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
  ; coefficients :
      'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
      * 'caml_f array point_evaluations
  ; generic_selector : 'caml_f array point_evaluations
  ; poseidon_selector : 'caml_f array point_evaluations
  ; complete_add_selector : 'caml_f array point_evaluations
  ; mul_selector : 'caml_f array point_evaluations
  ; emul_selector : 'caml_f array point_evaluations
  ; endomul_scalar_selector : 'caml_f array point_evaluations
  ; range_check0_selector : 'caml_f array point_evaluations option
  ; range_check1_selector : 'caml_f array point_evaluations option
  ; foreign_field_add_selector : 'caml_f array point_evaluations option
  ; foreign_field_mul_selector : 'caml_f array point_evaluations option
  ; xor_selector : 'caml_f array point_evaluations option
  ; rot_selector : 'caml_f array point_evaluations option
  ; lookup_aggregation : 'caml_f array point_evaluations option
  ; lookup_table : 'caml_f array point_evaluations option
  ; lookup_sorted : 'caml_f array point_evaluations option array
  ; runtime_lookup_table : 'caml_f array point_evaluations option
  ; runtime_lookup_table_selector : 'caml_f array point_evaluations option
  ; xor_lookup_selector : 'caml_f array point_evaluations option
  ; lookup_gate_lookup_selector : 'caml_f array point_evaluations option
  ; range_check_lookup_selector : 'caml_f array point_evaluations option
  ; foreign_field_mul_lookup_selector : 'caml_f array point_evaluations option
  }

type nonrec 'caml_g poly_comm =
  { unshifted : 'caml_g array; shifted : 'caml_g option }

type nonrec ('caml_g, 'caml_f) recursion_challenge =
  { chals : 'caml_f array; comm : 'caml_g poly_comm }

type nonrec ('g, 'f) opening_proof =
  { lr : ('g * 'g) array; delta : 'g; z1 : 'f; z2 : 'f; sg : 'g }

type nonrec ('g, 'f) pairing_proof = { quotient : 'g; blinding : 'f }

type nonrec 'caml_g lookup_commitments =
  { sorted : 'caml_g poly_comm array
  ; aggreg : 'caml_g poly_comm
  ; runtime : 'caml_g poly_comm option
  }

type nonrec 'caml_f runtime_table_cfg =
  { id : int32; first_column : 'caml_f array }

type nonrec 'caml_f lookup_table = { id : int32; data : 'caml_f array array }

type nonrec 'caml_f runtime_table = { id : int32; data : 'caml_f array }

type nonrec 'caml_g prover_commitments =
  { w_comm :
      'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
      * 'caml_g poly_comm
  ; z_comm : 'caml_g poly_comm
  ; t_comm : 'caml_g poly_comm
  ; lookup : 'caml_g lookup_commitments option
  }

type nonrec ('caml_g, 'caml_f, 'caml_p) prover_proof =
  { commitments : 'caml_g prover_commitments
  ; proof : 'caml_p
  ; evals : 'caml_f proof_evaluations
  ; ft_eval1 : 'caml_f
  ; public : 'caml_f array
  ; prev_challenges : ('caml_g, 'caml_f) recursion_challenge array
  }

type nonrec ('caml_g, 'caml_f, 'caml_p) proof_with_public =
  { public_evals : 'caml_f array point_evaluations option
  ; proof : ('caml_g, 'caml_f, 'caml_p) prover_proof
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
  | Lookup
  | CairoClaim
  | CairoInstruction
  | CairoFlags
  | CairoTransition
  | RangeCheck0
  | RangeCheck1
  | ForeignFieldAdd
  | ForeignFieldMul
  | Xor16
  | Rot64

type nonrec lookup_pattern = Xor | Lookup | RangeCheck | ForeignFieldMul

type nonrec lookup_patterns =
  { xor : bool; lookup : bool; range_check : bool; foreign_field_mul : bool }

type nonrec lookup_features =
  { patterns : lookup_patterns
  ; joint_lookup_used : bool
  ; uses_runtime_tables : bool
  }

type nonrec feature_flag =
  | RangeCheck0
  | RangeCheck1
  | ForeignFieldAdd
  | ForeignFieldMul
  | Xor
  | Rot
  | LookupTables
  | RuntimeLookupTables
  | LookupPattern of lookup_pattern
  | TableWidth of int
  | LookupsPerRow of int

type nonrec 'f circuit_gate =
  { typ : gate_type
  ; wires : wire * wire * wire * wire * wire * wire * wire
  ; coeffs : 'f array
  }

type nonrec curr_or_next = Curr | Next

type nonrec 'f oracles =
  { o : 'f random_oracles
  ; p_eval : 'f * 'f
  ; opening_prechallenges : 'f array
  ; digest_before_evaluations : 'f
  }

module VerifierIndex = struct
  module Lookup = struct
    type nonrec lookups_used = Single | Joint

    type nonrec lookup_info =
      { max_per_row : int; max_joint_size : int; features : lookup_features }

    type nonrec 't lookup_selectors =
      { lookup : 't option
      ; xor : 't option
      ; range_check : 't option
      ; ffmul : 't option
      }

    type nonrec 'poly_comm t =
      { joint_lookup_used : bool
      ; lookup_table : 'poly_comm array
      ; lookup_selectors : 'poly_comm lookup_selectors
      ; table_ids : 'poly_comm option
      ; lookup_info : lookup_info
      ; runtime_tables_selector : 'poly_comm option
      }
  end

  type nonrec 'fr domain = { log_size_of_group : int; group_gen : 'fr }

  type nonrec 'poly_comm verification_evals =
    { sigma_comm : 'poly_comm array
    ; coefficients_comm : 'poly_comm array
    ; generic_comm : 'poly_comm
    ; psm_comm : 'poly_comm
    ; complete_add_comm : 'poly_comm
    ; mul_comm : 'poly_comm
    ; emul_comm : 'poly_comm
    ; endomul_scalar_comm : 'poly_comm
    ; xor_comm : 'poly_comm option
    ; range_check0_comm : 'poly_comm option
    ; range_check1_comm : 'poly_comm option
    ; foreign_field_add_comm : 'poly_comm option
    ; foreign_field_mul_comm : 'poly_comm option
    ; rot_comm : 'poly_comm option
    }

  type nonrec ('fr, 'srs, 'poly_comm) verifier_index =
    { domain : 'fr domain
    ; max_poly_size : int
    ; public : int
    ; prev_challenges : int
    ; srs : 'srs
    ; evals : 'poly_comm verification_evals
    ; shifts : 'fr array
    ; lookup_index : 'poly_comm Lookup.t option
    }
end
