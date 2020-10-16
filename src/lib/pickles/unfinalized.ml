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
  , Other_field.t Shifted_value.t
  , ( Field.t Scalar_challenge.t Bulletproof_challenge.t
    , Tock.Rounds.n )
    Pickles_types.Vector.t
  , Field.t )
  Types.Pairing_based.Proof_state.Per_proof.In_circuit.t
  * Boolean.var

module Constant = struct
  open Zexe_backend

  type t =
    ( Challenge.Constant.t
    , Challenge.Constant.t Scalar_challenge.t
    , Tock.Field.t Shifted_value.t
    , ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
      , Tock.Rounds.n )
      Vector.t
    , Digest.Constant.t )
    Types.Pairing_based.Proof_state.Per_proof.In_circuit.t

  let shift = Shifted_value.Shift.create (module Tock.Field)

  let dummy : t =
    let one_chal = Challenge.Constant.dummy in
    let open Ro in
    let alpha = scalar_chal () in
    let beta = chal () in
    let gamma = chal () in
    let zeta = scalar_chal () in
    { deferred_values=
        { plonk=
            { (Plonk_checks.derive_plonk
                 (module Tock.Field)
                 ~shift ~endo:Endo.Dum.base (* I think this is right *)
                 ~mds:Tock_field_sponge.params.mds
                 ~domain:
                   (Plonk_checks.domain
                      (module Tock.Field)
                      wrap_domains.h ~shifts:Tock.B.Field_verifier_index.shifts
                      ~domain_generator:Tock.Field.domain_generator)
                 { alpha= Common.Ipa.Wrap.endo_to_field alpha
                 ; beta= Challenge.Constant.to_tock_field beta
                 ; gamma= Challenge.Constant.to_tock_field gamma
                 ; zeta= Common.Ipa.Wrap.endo_to_field zeta }
                 Dummy.evals_combined)
              with
              alpha
            ; beta
            ; gamma
            ; zeta }
        ; combined_inner_product= Shifted_value (tock ())
        ; xi= Scalar_challenge one_chal
        ; bulletproof_challenges= Dummy.Ipa.Wrap.challenges
        ; b= Shifted_value (tock ()) }
    ; sponge_digest_before_evaluations= Digest.Constant.dummy }
end
