open Core_kernel
open Pairing_marlin_types

module Deferred_values : sig
  type ('challenge, 'fp) t =
    { xi: 'challenge
    ; beta_1: ('challenge, 'fp, 'fp Evals.Beta1.t) Accumulator.Input.t
    ; beta_2: ('challenge, 'fp, 'fp Evals.Beta2.t) Accumulator.Input.t
    ; beta_3: ('challenge, 'fp, 'fp Evals.Beta3.t) Accumulator.Input.t
    ; sigma_2: 'fp
    ; sigma_3: 'fp
    ; alpha: 'challenge
    ; eta_A: 'challenge
    ; eta_B: 'challenge
    ; eta_C: 'challenge }

  include Intf.Snarkable.S2 with type ('a, 'b) t := ('a, 'b) t

  val assert_equal : ('a -> 'a -> unit) -> ('a, 'a) t -> ('a, 'a) t -> unit
end

type ('challenge, 'fp, 'fq, 'g1, 'kpc, 'bppc, 'digest, 's) t =
  { deferred_values: ('challenge, 'fp) Deferred_values.t
  ; pairing_marlin_index: 'kpc Abc.t Matrix_evals.t
  ; sponge_digest: 'digest
  ; bp_challenges_old: 'fq array (* Bullet proof challenges *)
  ; b_challenge_old: 'fq
  ; b_u_x_old: 'fq
  ; pairing_marlin_acc: 'g1 Pairing_marlin_types.Accumulator.t
        (* Purportedly b_{bp_challenges_old}(b_challenge_old) *)
        (* All this could be a hash which we unhash *)
  ; app_state: 's
  ; g_old: 'fp * 'fp
  ; dlog_marlin_index: 'bppc Abc.t Matrix_evals.t }

include
  Intf.Snarkable.S8
  with type ('a1, 'a2, 'a3, 'a4, 'a5, 'a6, 'a7, 'a8) t :=
              ('a1, 'a2, 'a3, 'a4, 'a5, 'a6, 'a7, 'a8) t
