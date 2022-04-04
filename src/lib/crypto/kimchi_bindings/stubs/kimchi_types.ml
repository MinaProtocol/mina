(* This file is generated automatically with ocaml_gen. *)
type nonrec 'F or_infinity = Infinity | Finite of ('F * 'F)

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

module VerifierIndex = struct
  module Lookup = struct
    type nonrec lookups_used = Single | Joint

    type nonrec 'PolyComm t =
      { lookup_used : lookups_used
      ; lookup_table : 'PolyComm array
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
end
