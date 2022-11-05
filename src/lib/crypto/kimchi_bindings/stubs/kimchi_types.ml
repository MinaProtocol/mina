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
[@@boxed]

type nonrec 'evals point_evaluations = { zeta : 'evals; zeta_omega : 'evals }
[@@boxed]

type nonrec 'caml_f lookup_evaluations =
  { sorted : 'caml_f array point_evaluations array
  ; aggreg : 'caml_f array point_evaluations
  ; table : 'caml_f array point_evaluations
  ; runtime : 'caml_f array point_evaluations option
  }
[@@boxed]

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
  ; generic_selector : 'caml_f array point_evaluations
  ; poseidon_selector : 'caml_f array point_evaluations
  ; lookup : 'caml_f lookup_evaluations option
  }
[@@boxed]

type nonrec 'caml_g poly_comm =
  { unshifted : 'caml_g array; shifted : 'caml_g option }
[@@boxed]

type nonrec ('caml_g, 'caml_f) recursion_challenge =
  { chals : 'caml_f array; comm : 'caml_g poly_comm }
[@@boxed]

type nonrec ('g, 'f) opening_proof =
  { lr : ('g * 'g) array; delta : 'g; z1 : 'f; z2 : 'f; sg : 'g }
[@@boxed]

type nonrec 'caml_g lookup_commitments =
  { sorted : 'caml_g poly_comm array
  ; aggreg : 'caml_g poly_comm
  ; runtime : 'caml_g poly_comm option
  }
[@@boxed]

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
[@@boxed]

type nonrec ('caml_g, 'caml_f) prover_proof =
  { commitments : 'caml_g prover_commitments
  ; proof : ('caml_g, 'caml_f) opening_proof
  ; evals : 'caml_f proof_evaluations
  ; ft_eval1 : 'caml_f
  ; public : 'caml_f array
  ; prev_challenges : ('caml_g, 'caml_f) recursion_challenge array
  }
[@@boxed]

type nonrec wire = { row : int; col : int } [@@boxed]

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
  | Lookup
  | CairoClaim
  | CairoInstruction
  | CairoFlags
  | CairoTransition
  | RangeCheck0
  | RangeCheck1
  | ForeignFieldAdd
  | Xor16

type nonrec 'f circuit_gate =
  { typ : gate_type
  ; wires : wire * wire * wire * wire * wire * wire * wire
  ; coeffs : 'f array
  }
[@@boxed]

type nonrec curr_or_next = Curr | Next

type nonrec 'f oracles =
  { o : 'f random_oracles
  ; p_eval : 'f * 'f
  ; opening_prechallenges : 'f array
  ; digest_before_evaluations : 'f
  }
[@@boxed]

module VerifierIndex = struct
  module Lookup = struct
    type nonrec lookups_used = Single | Joint

    type nonrec 't lookup_selectors = { lookup_gate : 't option } [@@boxed]

    type nonrec 'poly_comm t =
      { lookup_used : lookups_used
      ; lookup_table : 'poly_comm array
      ; lookup_selectors : 'poly_comm lookup_selectors
      ; table_ids : 'poly_comm option
      ; max_joint_size : int
      ; runtime_tables_selector : 'poly_comm option
      }
    [@@boxed]
  end

  type nonrec 'fr domain = { log_size_of_group : int; group_gen : 'fr }
  [@@boxed]

  type nonrec 'poly_comm verification_evals =
    { sigma_comm : 'poly_comm array
    ; coefficients_comm : 'poly_comm array
    ; generic_comm : 'poly_comm
    ; psm_comm : 'poly_comm
    ; complete_add_comm : 'poly_comm
    ; mul_comm : 'poly_comm
    ; emul_comm : 'poly_comm
    ; endomul_scalar_comm : 'poly_comm
    ; chacha_comm : 'poly_comm array option
    }
  [@@boxed]

  type nonrec ('fr, 'srs, 'poly_comm) verifier_index =
    { domain : 'fr domain
    ; max_poly_size : int
    ; max_quot_size : int
    ; public : int
    ; prev_challenges : int
    ; srs : 'srs
    ; evals : 'poly_comm verification_evals
    ; shifts : 'fr array
    ; lookup_index : 'poly_comm Lookup.t option
    }
  [@@boxed]
end
