open Import
open Types
open Pickles_types
open Hlist
open Snarky_backendless.Request
open Backend

module Wrap = struct
  module type S = sig
    type max_proofs_verified

    type max_local_max_proofs_verifieds

    open Impls.Wrap
    open Snarky_backendless.Request

    type _ t +=
      | Evals :
          ( (Field.Constant.t, Field.Constant.t array) Plonk_types.All_evals.t
          , max_proofs_verified )
          Vector.t
          t
      | Which_branch : int t
      | Step_accs : (Tock.Inner_curve.Affine.t, max_proofs_verified) Vector.t t
      | Old_bulletproof_challenges :
          max_local_max_proofs_verifieds H1.T(Challenges_vector.Constant).t t
      | Proof_state :
          ( ( ( Challenge.Constant.t
              , Challenge.Constant.t Scalar_challenge.t
              , Field.Constant.t Shifted_value.Type2.t
              , ( Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
                , Tock.Rounds.n )
                Vector.t
              , Digest.Constant.t
              , bool )
              Types.Step.Proof_state.Per_proof.In_circuit.t
            , max_proofs_verified )
            Vector.t
          , Digest.Constant.t )
          Types.Step.Proof_state.t
          t
      | Messages : Tock.Inner_curve.Affine.t Plonk_types.Messages.t t
      | Openings_proof :
          ( Tock.Inner_curve.Affine.t
          , Tick.Field.t )
          Plonk_types.Openings.Bulletproof.t
          t
      | Wrap_domain_indices : (Field.Constant.t, max_proofs_verified) Vector.t t
  end

  type ('mb, 'ml) t =
    (module S
       with type max_proofs_verified = 'mb
        and type max_local_max_proofs_verifieds = 'ml )

  let create : type mb ml. unit -> (mb, ml) t =
   fun () ->
    let module R = struct
      type nonrec max_proofs_verified = mb

      type nonrec max_local_max_proofs_verifieds = ml

      open Snarky_backendless.Request

      type 'a vec = ('a, max_proofs_verified) Vector.t

      type _ t +=
        | Evals :
            (Tock.Field.t, Tock.Field.t array) Plonk_types.All_evals.t vec t
        | Which_branch : int t
        | Step_accs : Tock.Inner_curve.Affine.t vec t
        | Old_bulletproof_challenges :
            max_local_max_proofs_verifieds H1.T(Challenges_vector.Constant).t t
        | Proof_state :
            ( ( ( Challenge.Constant.t
                , Challenge.Constant.t Scalar_challenge.t
                , Tock.Field.t Shifted_value.Type2.t
                , ( Challenge.Constant.t Scalar_challenge.t
                    Bulletproof_challenge.t
                  , Tock.Rounds.n )
                  Vector.t
                , Digest.Constant.t
                , bool )
                Types.Step.Proof_state.Per_proof.In_circuit.t
              , max_proofs_verified )
              Vector.t
            , Digest.Constant.t )
            Types.Step.Proof_state.t
            t
        | Messages : Tock.Inner_curve.Affine.t Plonk_types.Messages.t t
        | Openings_proof :
            ( Tock.Inner_curve.Affine.t
            , Tick.Field.t )
            Plonk_types.Openings.Bulletproof.t
            t
        | Wrap_domain_indices : (Tock.Field.t, max_proofs_verified) Vector.t t
    end in
    (module R)
end

(* The requests for a single predecessor, together with the compile-time data
   fixing its witness layout. The constructors are exposed so a predecessor's
   handler can be a single [match] over them rather than a per-request
   closure. *)
module type Prev_request = sig
  type width

  (* This predecessor's max-proofs-verified width, as a value. *)
  val width : width Nat.t

  (* This predecessor's feature flags, fixing its witness layout. *)
  val feature_flags : Opt.Flag.t Plonk_types.Features.Full.t

  (* The number of polynomial chunks in this predecessor's proof. *)
  val num_chunks : int

  (* This predecessor's witness [Typ], fixed by [width], [feature_flags] and
     [num_chunks]. A thunk because the branch-count index is phantom and so
     must stay universally quantified. *)
  val typ :
       unit
    -> ( (unit, width, _) Per_proof_witness.t
       , (unit, width) Per_proof_witness.Constant.t )
       Impls.Step.Typ.t

  type _ Snarky_backendless.Request.t +=
    | Witness :
        (unit, width) Per_proof_witness.Constant.t Snarky_backendless.Request.t
          (** This predecessor's witness. *)
    | Unfinalized : Unfinalized.Constant.t Snarky_backendless.Request.t
          (** This predecessor's unfinalized proof. *)
    | Messages_for_next_wrap_proof :
        Digest.Constant.t Snarky_backendless.Request.t
          (** This predecessor's messages-for-next-wrap-proof digest. *)
end

module type Prev_spec = sig
  include Nat.Intf

  val feature_flags : Opt.Flag.t Plonk_types.Features.Full.t

  val num_chunks : int
end

(* Mint a fresh set of requests for one predecessor. The [()] makes each
   application generative, so each predecessor's constructors are distinct: the
   step circuit fires them directly, and each predecessor's handler matches its
   own constructors against its own witnessed values (see [step.ml]). *)
module Make_prev_request (Spec : Prev_spec) () :
  Prev_request with type width = Spec.n = struct
  type width = Spec.n

  let width = Spec.n

  let feature_flags = Spec.feature_flags

  let num_chunks = Spec.num_chunks

  let typ () =
    Per_proof_witness.typ Impls.Step.Typ.unit Spec.n
      ~feature_flags:Spec.feature_flags ~num_chunks:Spec.num_chunks

  type _ Snarky_backendless.Request.t +=
    | Witness :
        (unit, Spec.n) Per_proof_witness.Constant.t Snarky_backendless.Request.t
    | Unfinalized : Unfinalized.Constant.t Snarky_backendless.Request.t
    | Messages_for_next_wrap_proof :
        Digest.Constant.t Snarky_backendless.Request.t
end

(* [Prev_request] packed first-class, for carrying one per predecessor in an
   hlist indexed by the predecessor widths. *)
module Prev_request_packed = struct
  type 'width t = (module Prev_request with type width = 'width)
end

module Step (Inductive_rule : Inductive_rule.Intf) = struct
  module type S = sig
    type statement

    type return_value

    type prev_values

    type proofs_verified

    (* TODO: As an optimization this can be the local proofs-verified size *)
    type max_proofs_verified

    type local_signature

    type local_branches

    type auxiliary_value

    type _ t +=
      | Compute_prev_proof_parts :
          ( prev_values
          , local_signature )
          H2.T(Inductive_rule.Previous_proof_statement.Constant).t
          -> unit Promise.t t
      | Wrap_index : Tock.Curve.Affine.t array Plonk_verification_key_evals.t t
      | App_state : statement t
      | Return_value : return_value -> unit t
      | Auxiliary_value : auxiliary_value -> unit t
      | Dummy_messages_for_next_wrap_proof : Digest.Constant.t t
  end

  let create :
      type proofs_verified local_signature local_branches statement return_value auxiliary_value prev_values max_proofs_verified.
         unit
      -> (module S
            with type local_signature = local_signature
             and type local_branches = local_branches
             and type statement = statement
             and type return_value = return_value
             and type auxiliary_value = auxiliary_value
             and type prev_values = prev_values
             and type proofs_verified = proofs_verified
             and type max_proofs_verified = max_proofs_verified ) =
   fun () ->
    let module R = struct
      type nonrec max_proofs_verified = max_proofs_verified

      type nonrec proofs_verified = proofs_verified

      type nonrec statement = statement

      type nonrec return_value = return_value

      type nonrec auxiliary_value = auxiliary_value

      type nonrec prev_values = prev_values

      type nonrec local_signature = local_signature

      type nonrec local_branches = local_branches

      type _ t +=
        | Compute_prev_proof_parts :
            ( prev_values
            , local_signature )
            H2.T(Inductive_rule.Previous_proof_statement.Constant).t
            -> unit Promise.t t
        | Wrap_index :
            Tock.Curve.Affine.t array Plonk_verification_key_evals.t t
        | App_state : statement t
        | Return_value : return_value -> unit t
        | Auxiliary_value : auxiliary_value -> unit t
        | Dummy_messages_for_next_wrap_proof : Digest.Constant.t t
    end in
    (module R)
end
