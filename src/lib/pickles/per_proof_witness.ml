open Backend
open Pickles_types
open Import
module Impl = Impls.Step
module One_hot_vector = One_hot_vector.Make (Impl)

(** Represents a proof (along with its accumulation state) which wraps a
    "step" proof S on the other curve.

    To have some notation, the proof S itself comes from a circuit that verified
    up to 'max_branching many wrap proofs W_0, ..., W_max_branching.
*)
type ('app_state, 'max_branching, 'num_branches) t =
  { app_state : 'app_state
        (** The user-level statement corresponding to this proof. *)
  ; wrap_proof : Wrap_proof.Checked.t
        (** The polynomial commitments, polynomial evaluations, and opening proof corresponding to
      this latest wrap proof.
  *)
  ; proof_state :
      ( Challenge.Make(Impl).t
      , Challenge.Make(Impl).t Scalar_challenge.t
      , Impl.Field.t Shifted_value.Type1.t
      , Step_verifier.Make(Step_main_inputs).Other_field.t
      , unit
      , Digest.Make(Impl).t
      , Challenge.Make(Impl).t Scalar_challenge.t Types.Bulletproof_challenge.t
        Types.Step_bp_vec.t
      , 'num_branches One_hot_vector.t )
      Types.Wrap.Proof_state.In_circuit.t
        (** The accumulator state corresponding to the above proof. Contains
      - `deferred_values`: The values necessary for finishing the deferred "scalar field" computations.
      That is, computations which are over the "step" circuit's internal field that the
      previous "wrap" circuit was unable to verify directly, due to its internal field
      being different.
      - `sponge_digest_before_evaluations`: the sponge state: TODO
      - me_only
  *)
  ; prev_proof_evals :
      (Impl.Field.t, Impl.Field.t array) Plonk_types.All_evals.t
        (** The evaluations from the step proof that this proof wraps *)
  ; prev_challenges :
      ((Impl.Field.t, Tick.Rounds.n) Vector.t, 'max_branching) Vector.t
        (** The challenges c_0, ... c_{k - 1} corresponding to each W_i. *)
  ; prev_challenge_polynomial_commitments :
      (Step_main_inputs.Inner_curve.t, 'max_branching) Vector.t
        (** The commitments to the "challenge polynomials" \prod_{i = 0}^k (1 + c_{k - 1 - i} x^{2^i})
      corresponding to each of the "prev_challenges".
  *)
  }
[@@deriving hlist]

module Constant = struct
  open Kimchi_backend

  type ('local_statement, 'local_max_branching, _) t =
    { app_state : 'local_statement
    ; wrap_proof : Wrap_proof.Constant.t
    ; proof_state :
        ( Challenge.Constant.t
        , Challenge.Constant.t Scalar_challenge.t
        , Tick.Field.t Shifted_value.Type1.t
        , Tock.Field.t
        , unit
        , Digest.Constant.t
        , Challenge.Constant.t Scalar_challenge.t Types.Bulletproof_challenge.t
          Types.Step_bp_vec.t
        , Types.Index.t )
        Types.Wrap.Proof_state.In_circuit.t
    ; prev_proof_evals :
        (Tick.Field.t, Tick.Field.t array) Plonk_types.All_evals.t
    ; prev_challenges :
        ((Tick.Field.t, Tick.Rounds.n) Vector.t, 'local_max_branching) Vector.t
    ; prev_challenge_polynomial_commitments :
        (Tick.Inner_curve.Affine.t, 'local_max_branching) Vector.t
    }
  [@@deriving hlist]
end

open Core_kernel

let typ (type n avar aval m) (statement : (avar, aval) Impls.Step.Typ.t)
    (local_max_branching : n Nat.t) (local_branches : m Nat.t) :
    ((avar, n, m) t, (aval, n, m) Constant.t) Impls.Step.Typ.t =
  let open Impls.Step in
  let open Step_main_inputs in
  let open Step_verifier in
  let index =
    Typ.transport (One_hot_vector.typ local_branches) ~there:Types.Index.to_int
      ~back:(fun x -> Option.value_exn (Types.Index.of_int x))
  in
  Snarky_backendless.Typ.of_hlistable ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:Constant.to_hlist
    ~value_of_hlist:Constant.of_hlist
    [ statement
    ; Wrap_proof.typ
    ; Types.Wrap.Proof_state.In_circuit.typ ~challenge:Challenge.typ
        ~scalar_challenge:Challenge.typ
        (Shifted_value.Type1.typ Field.typ)
        Other_field.typ
        (Snarky_backendless.Typ.unit ())
        Digest.typ index
    ; (let lengths = Evaluation_lengths.create ~of_int:Fn.id in
       Plonk_types.All_evals.typ lengths Field.typ ~default:Field.Constant.zero)
    ; Vector.typ (Vector.typ Field.typ Tick.Rounds.n) local_max_branching
    ; Vector.typ Inner_curve.typ local_max_branching
    ]
