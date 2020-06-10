open Core
open Pickles_types
open Import
open Types
open Common
open Zexe_backend

module Base = struct
  module Me_only = Reduced_me_only

  module Pairing_based = struct
    type ('s, 'unfinalized_proofs, 'sgs, 'dlog_me_onlys, 'prev_evals) t =
      { statement:
          ( 'unfinalized_proofs
          , ('s, 'sgs) Me_only.Pairing_based.t
          , 'dlog_me_onlys )
          Types.Pairing_based.Statement.t
      ; index: int
      ; prev_evals: 'prev_evals
      ; proof: Pairing_based.Proof.t }
  end

  module Dlog_based = struct
    type ('s, 'dlog_me_only, 'sgs) t =
      { statement:
          ( Challenge.Constant.t
          , Challenge.Constant.t Scalar_challenge.Stable.Latest.t
          , Fp.t
          , bool
          , Fq.t
          , 'dlog_me_only
          , Digest.Constant.t
          , ('s, 'sgs) Me_only.Pairing_based.t )
          Types.Dlog_based.Statement.t
      ; index: int
      ; prev_evals: Fp.t Pairing_marlin_types.Evals.Stable.Latest.t
      ; prev_x_hat_beta_1: Fp.t
      ; proof: Dlog_based.Proof.t }
    [@@deriving bin_io, compare, sexp, yojson]
  end
end

type ('max_width, 'mlmb) t =
  ( unit
  , 'mlmb Base.Me_only.Dlog_based.t
  , (G.Affine.t, 'max_width) Vector.t )
  Base.Dlog_based.t

let dummy (type w h) (w : w Nat.t) (h : h Nat.t) : (w, h) t =
  let open Ro in
  let g0 = G.(to_affine_exn one) in
  let g len = Array.create ~len g0 in
  let fq len = Array.init len ~f:(fun _ -> fq ()) in
  let lengths = Commitment_lengths.of_domains Common.wrap_domains in
  { statement=
      { proof_state=
          { deferred_values=
              { xi= scalar_chal ()
              ; r= scalar_chal ()
              ; r_xi_sum= fp ()
              ; marlin=
                  { sigma_2= fp ()
                  ; sigma_3= fp ()
                  ; alpha= chal ()
                  ; eta_a= chal ()
                  ; eta_b= chal ()
                  ; eta_c= chal ()
                  ; beta_1= scalar_chal ()
                  ; beta_2= scalar_chal ()
                  ; beta_3= scalar_chal () } }
          ; sponge_digest_before_evaluations=
              Digest.Constant.of_fq Zexe_backend.Fq.zero
          ; was_base_case= true
          ; me_only=
              { pairing_marlin_acc= Lazy.force Dummy.pairing_acc
              ; old_bulletproof_challenges=
                  Vector.init h ~f:(fun _ ->
                      Unfinalized.Constant.dummy_bulletproof_challenges ) } }
      ; pass_through=
          { app_state= ()
          ; sg=
              Vector.init w ~f:(fun _ ->
                  Lazy.force Unfinalized.Constant.corresponding_dummy_sg ) } }
  ; proof=
      { messages=
          { w_hat= g lengths.w_hat
          ; z_hat_a= g lengths.z_hat_a
          ; z_hat_b= g lengths.z_hat_a
          ; gh_1= ({unshifted= g lengths.g_1; shifted= g0}, g lengths.h_1)
          ; sigma_gh_2=
              ( Ro.fq ()
              , ({unshifted= g lengths.g_2; shifted= g0}, g lengths.h_2) )
          ; sigma_gh_3=
              ( Ro.fq ()
              , ({unshifted= g lengths.g_3; shifted= g0}, g lengths.h_3) ) }
      ; openings=
          { proof=
              { lr= Array.init (Nat.to_int Rounds.n) ~f:(fun _ -> (g0, g0))
              ; z_1= Ro.fq ()
              ; z_2= Ro.fq ()
              ; delta= g0
              ; sg= g0 }
          ; evals=
              (let e = Dlog_marlin_types.Evals.map lengths ~f:fq in
               (e, e, e)) } }
  ; prev_evals=
      (let abc () = {Abc.a= fp (); b= fp (); c= fp ()} in
       { w_hat= fp ()
       ; z_hat_a= fp ()
       ; z_hat_b= fp ()
       ; g_1= fp ()
       ; h_1= fp ()
       ; g_2= fp ()
       ; h_2= fp ()
       ; g_3= fp ()
       ; h_3= fp ()
       ; row= abc ()
       ; col= abc ()
       ; value= abc ()
       ; rc= abc () })
  ; prev_x_hat_beta_1= fp ()
  ; index= 0 }

module Make (W : Nat.Intf) (MLMB : Nat.Intf) = struct
  module Max_branching_vec = Nvector (W)
  module MLMB_vec = Nvector (MLMB)

  type t =
    ( unit
    , ( G1.Affine.t
      , G1.Affine.t Unshifted_acc.Stable.Latest.t
      , Reduced_me_only.Dlog_based.Challenges_vector.t MLMB_vec.t )
      Types.Dlog_based.Proof_state.Me_only.t
    , G.Affine.t Max_branching_vec.t )
    Base.Dlog_based.t
  [@@deriving bin_io, compare, sexp, yojson]
end

module With_data = struct
  type ('s, 'max_width, 'max_height) t =
    ( 's
    , 'max_width Base.Me_only.Dlog_based.t
    , (G.Affine.t, 'max_width) Vector.t )
    Base.Dlog_based.t
end
