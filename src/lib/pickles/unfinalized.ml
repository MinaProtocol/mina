open Backend
open Impls.Step
open Pickles_types
open Common
open Import

(* Unfinalized dlog-based proof, along with a flag which is true iff it
   is expected to verify. This allows for situations like the blockchain
   SNARK where we let the previous proof fail in the base case.
*)
type t =
  ( Field.t
  , Field.t Scalar_challenge.t
  , Other_field.t
  , ( (Field.t Scalar_challenge.t, Boolean.var) Bulletproof_challenge.t
    , Tock.Rounds.n )
    Pickles_types.Vector.t
  , Field.t )
  Types.Pairing_based.Proof_state.Per_proof.t
  * Boolean.var

module Constant = struct
  open Zexe_backend

  type t =
    ( Challenge.Constant.t
    , Challenge.Constant.t Scalar_challenge.t
    , Tock.Field.t
    , ( (Challenge.Constant.t Scalar_challenge.t, bool) Bulletproof_challenge.t
      , Tock.Rounds.n )
      Vector.t
    , Digest.Constant.t )
    Types.Pairing_based.Proof_state.Per_proof.t

  let dummy : t =
    let one_chal = Challenge.Constant.dummy in
    let open Ro in
    { deferred_values=
        { marlin=
            { sigma_2= tock ()
            ; sigma_3= tock ()
            ; alpha= chal ()
            ; eta_a= chal ()
            ; eta_b= chal ()
            ; eta_c= chal ()
            ; beta_1= Scalar_challenge (chal ())
            ; beta_2= Scalar_challenge (chal ())
            ; beta_3= Scalar_challenge (chal ()) }
        ; combined_inner_product= tock ()
        ; xi= Scalar_challenge one_chal
        ; bulletproof_challenges= Dummy.Ipa.Wrap.challenges
        ; b= tock () }
    ; sponge_digest_before_evaluations= Digest.Constant.dummy }
end
