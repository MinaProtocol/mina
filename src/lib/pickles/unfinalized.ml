open Impls.Pairing_based
open Pickles_types
open Common

(* Unfinalized dlog-based proof *)
type t =
  ( Field.t
  , Field.t Scalar_challenge.t
  , Fq.t
  , ( (Field.t Scalar_challenge.t, Boolean.var) Bulletproof_challenge.t
    , Rounds.n )
    Pickles_types.Vector.t
  , Field.t )
  Types.Pairing_based.Proof_state.Per_proof.t
  * Boolean.var

module Constant = struct
  open Zexe_backend

  type t =
    ( Challenge.Constant.t
    , Challenge.Constant.t Scalar_challenge.t
    , Fq.t
    , ( (Challenge.Constant.t Scalar_challenge.t, bool) Bulletproof_challenge.t
      , Rounds.n )
      Vector.t
    , Digest.Constant.t )
    Types.Pairing_based.Proof_state.Per_proof.t

  let dummy_bulletproof_challenges =
    Vector.init Rounds.n ~f:(fun _ ->
        let prechallenge = Ro.scalar_chal () in
        { Bulletproof_challenge.is_square=
            Fq.is_square (Endo.Dlog.to_field prechallenge)
        ; prechallenge } )

  let dummy_bulletproof_challenges_computed =
    Vector.map dummy_bulletproof_challenges
      ~f:(fun {is_square; prechallenge} ->
        (compute_challenge ~is_square prechallenge : Fq.t) )

  let dummy : t =
    let one_chal = Challenge.Constant.dummy in
    let open Ro in
    { deferred_values=
        { marlin=
            { sigma_2= fq ()
            ; sigma_3= fq ()
            ; alpha= chal ()
            ; eta_a= chal ()
            ; eta_b= chal ()
            ; eta_c= chal ()
            ; beta_1= Scalar_challenge (chal ())
            ; beta_2= Scalar_challenge (chal ())
            ; beta_3= Scalar_challenge (chal ()) }
        ; combined_inner_product= fq ()
        ; xi= Scalar_challenge one_chal
        ; r= Scalar_challenge one_chal
        ; bulletproof_challenges= dummy_bulletproof_challenges
        ; b= fq () }
    ; sponge_digest_before_evaluations= Digest.Constant.dummy }

  let corresponding_dummy_sg =
    lazy
      (Common.time "dummy sg" (fun () ->
           compute_sg dummy_bulletproof_challenges ))
end
