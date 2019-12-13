open Core_kernel
open Import

(* About 10000 bits altogether *)
module Deferred_values = struct
  open Pairing_marlin_types

  type ('challenge, 'fp) t =
    { xi: 'challenge (* 128 bits *)
    ; sigma_2: 'fp
    ; sigma_3: 'fp
    ; alpha: 'challenge (* 128 bits *)
    ; eta_A: 'challenge (* 128 bits *)
    ; eta_B: 'challenge (* 128 bits *)
    ; eta_C: 'challenge (* 128 bits *)
    ; beta_1: ('challenge, 'fp, 'fp Evals.Beta1.t) Accumulator.Input.t
    ; beta_2: ('challenge, 'fp, 'fp Evals.Beta2.t) Accumulator.Input.t
    ; beta_3: ('challenge, 'fp, 'fp Evals.Beta3.t) Accumulator.Input.t }
  [@@deriving fields]

  let assert_equal fp t1 t2 =
    let acc x = Accumulator.Input.assert_equal fp x in
    let check c p = c (p t1) (p t2) in
    check acc beta_1 ;
    check acc beta_2 ;
    check acc beta_3 ;
    List.iter ~f:(check fp) [xi; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C]

  let to_hlist
      {xi; beta_1; beta_2; beta_3; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C}
      =
    H_list.
      [xi; beta_1; beta_2; beta_3; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C]

  let of_hlist
      ([ xi
       ; beta_1
       ; beta_2
       ; beta_3
       ; sigma_2
       ; sigma_3
       ; alpha
       ; eta_A
       ; eta_B
       ; eta_C ] :
        (unit, _) H_list.t) =
    {xi; beta_1; beta_2; beta_3; sigma_2; sigma_3; alpha; eta_A; eta_B; eta_C}

  let typ challenge fp =
    let acc v = Accumulator.Input.typ challenge fp (v fp) in
    let open Evals in
    Snarky.Typ.of_hlistable
      [ challenge
      ; acc Beta1.typ
      ; acc Beta2.typ
      ; acc Beta3.typ
      ; fp
      ; fp
      ; challenge
      ; challenge
      ; challenge
      ; challenge ]
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist
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

let to_hlist
    { deferred_values
    ; pairing_marlin_index
    ; sponge_digest
    ; bp_challenges_old
    ; b_challenge_old
    ; b_u_x_old
    ; pairing_marlin_acc
    ; app_state
    ; g_old
    ; dlog_marlin_index } =
  H_list.
    [ deferred_values
    ; pairing_marlin_index
    ; sponge_digest
    ; bp_challenges_old
    ; b_challenge_old
    ; b_u_x_old
    ; pairing_marlin_acc
    ; app_state
    ; g_old
    ; dlog_marlin_index ]

let of_hlist
    ([ deferred_values
     ; pairing_marlin_index
     ; sponge_digest
     ; bp_challenges_old
     ; b_challenge_old
     ; b_u_x_old
     ; pairing_marlin_acc
     ; app_state
     ; g_old
     ; dlog_marlin_index ] :
      (unit, _) H_list.t) =
  { deferred_values
  ; pairing_marlin_index
  ; sponge_digest
  ; bp_challenges_old
  ; b_challenge_old
  ; b_u_x_old
  ; pairing_marlin_acc
  ; app_state
  ; g_old
  ; dlog_marlin_index }

let typ challenge fp fq g1 kpc bppc digest s =
  Snarky.Typ.of_hlistable
    [ Deferred_values.typ challenge fp
    ; Matrix_evals.typ (Abc.typ kpc)
    ; digest
    ; Snarky.Typ.array ~length:15 fq
    ; fq
    ; fq
    ; Pairing_marlin_types.Accumulator.typ g1
    ; s
    ; Snarky.Typ.tuple2 fp fp
    ; Matrix_evals.typ (Abc.typ bppc) ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist
