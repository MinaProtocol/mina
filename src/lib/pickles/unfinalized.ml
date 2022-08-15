open Core_kernel
open Backend
open Impls.Step
open Pickles_types
open Common
open Import
module Shifted_value = Shifted_value.Type2

(* Unfinalized dlog-based proof, along with a flag which is true iff it
   is expected to verify. This allows for situations like the blockchain
   SNARK where we let the previous proof fail in the base case.
*)
type t =
  ( Field.t
  , Field.t Scalar_challenge.t
  , Other_field.t Shifted_value.t
  , ( ( Field.t Scalar_challenge.t
      , Other_field.t Shifted_value.t )
      Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
    , Boolean.var )
    Plonk_types.Opt.t
  , ( Field.t Scalar_challenge.t Bulletproof_challenge.t
    , Tock.Rounds.n )
    Pickles_types.Vector.t
  , Field.t
  , Boolean.var )
  Types.Step.Proof_state.Per_proof.In_circuit.t

module Plonk_checks = struct
  include Plonk_checks
  include Plonk_checks.Make (Shifted_value) (Plonk_checks.Scalars.Tock)
end

module Constant = struct
  type t =
    ( Challenge.Constant.t
    , Challenge.Constant.t Scalar_challenge.t
    , Tock.Field.t Shifted_value.t
    , ( Challenge.Constant.t Scalar_challenge.t
      , Tock.Field.t Shifted_value.t )
      Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
      option
    , ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
      , Tock.Rounds.n )
      Vector.t
    , Digest.Constant.t
    , bool )
    Types.Step.Proof_state.Per_proof.In_circuit.t

  let shift = Shifted_value.Shift.create (module Tock.Field)

  let dummy () : t =
    let one_chal = Challenge.Constant.dummy in
    let open Ro in
    let alpha = scalar_chal () in
    let beta = chal () in
    let gamma = chal () in
    let zeta = scalar_chal () in
    let chals :
        _ Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t =
      { alpha = Common.Ipa.Wrap.endo_to_field alpha
      ; beta = Challenge.Constant.to_tock_field beta
      ; gamma = Challenge.Constant.to_tock_field gamma
      ; zeta = Common.Ipa.Wrap.endo_to_field zeta
      ; joint_combiner = None
      }
    in
    let evals =
      Plonk_types.Evals.to_in_circuit Dummy.evals_combined.evals.evals
    in
    let env =
      Plonk_checks.scalars_env
        (module Tock.Field)
        ~srs_length_log2:Common.Max_degree.wrap_log2
        ~endo:Endo.Wrap_inner_curve.base ~mds:Tock_field_sponge.params.mds
        ~field_of_hex:
          (Core_kernel.Fn.compose Tock.Field.of_bigint
             Kimchi_pasta.Pasta.Bigint256.of_hex_string )
        ~domain:
          (Plonk_checks.domain
             (module Tock.Field)
             (wrap_domains ~proofs_verified:2).h ~shifts:Common.tock_shifts
             ~domain_generator:Tock.Field.domain_generator )
        chals evals
    in
    let plonk =
      Plonk_checks.derive_plonk (module Tock.Field) ~env ~shift chals evals
    in
    { deferred_values =
        { plonk = { plonk with alpha; beta; gamma; zeta; lookup = None }
        ; combined_inner_product = Shifted_value (tock ())
        ; xi = Scalar_challenge.create one_chal
        ; bulletproof_challenges = Dummy.Ipa.Wrap.challenges
        ; b = Shifted_value (tock ())
        }
    ; should_finalize = false
    ; sponge_digest_before_evaluations = Digest.Constant.dummy
    }
end

let typ ~wrap_rounds ~uses_lookup : (t, Constant.t) Typ.t =
  Types.Step.Proof_state.Per_proof.typ
    (module Impl)
    (Shifted_value.typ Other_field.typ)
    ~assert_16_bits:(Step_verifier.assert_n_bits ~n:16)
    ~zero:Common.Lookup_parameters.tick_zero ~uses_lookup
