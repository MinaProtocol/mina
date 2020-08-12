open Backend
open Pickles_types
open Import
module Impl = Impls.Step
module One_hot_vector = One_hot_vector.Make (Impl)

type ('local_statement, 'local_max_branching, 'local_num_branches) t =
  'local_statement
  * ( Challenge.Make(Impl).t
    , Challenge.Make(Impl).t Scalar_challenge.t
    , Impl.Field.t
    , Impl.Boolean.var
    , Pairing_main.Make(Step_main_inputs).Other_field.t
    , unit
    , Digest.Make(Impl).t
    , ( Challenge.Make(Impl).t Scalar_challenge.t
      , Impl.Boolean.var )
      Types.Bulletproof_challenge.t
      Types.Bp_vec.t
    , 'local_num_branches One_hot_vector.t )
    Types.Dlog_based.Proof_state.t
  * (Impl.Field.t array Dlog_marlin_types.Evals.t * Impl.Field.t)
    Tuple_lib.Triple.t
  * (Step_main_inputs.Inner_curve.t, 'local_max_branching) Vector.t
  * ((Impl.Field.t, Rounds.n) Vector.t, 'local_max_branching) Vector.t
  * Wrap_proof.var

module Constant = struct
  open Zexe_backend

  type ('local_statement, 'local_max_branching, _) t =
    'local_statement
    * ( Challenge.Constant.t
      , Challenge.Constant.t Scalar_challenge.t
      , Tick.Field.t
      , bool
      , Tock.Field.t
      , unit
      , Digest.Constant.t
      , ( Challenge.Constant.t Scalar_challenge.t
        , bool )
        Types.Bulletproof_challenge.t
        Types.Bp_vec.t
      , Types.Index.t )
      Types.Dlog_based.Proof_state.t
    * (Tick.Field.t array Dlog_marlin_types.Evals.t * Tick.Field.t)
      Tuple_lib.Triple.t
    * (Tick.Inner_curve.Affine.t, 'local_max_branching) Vector.t
    * ((Tick.Field.t, Rounds.n) Vector.t, 'local_max_branching) Vector.t
    * Wrap_proof.t
end

open Core_kernel

let typ (type n avar aval m) (statement : (avar, aval) Impls.Step.Typ.t)
    (local_max_branching : n Nat.t) (local_branches : m Nat.t) ~step_domains :
    ((avar, n, m) t, (aval, n, m) Constant.t) Impls.Step.Typ.t =
  let open Impls.Step in
  let open Step_main_inputs in
  let open Pairing_main in
  let index =
    Typ.transport (One_hot_vector.typ local_branches) ~there:Types.Index.to_int
      ~back:(fun x -> Option.value_exn (Types.Index.of_int x))
  in
  Snarky_backendless.Typ.tuple6 statement
    (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ Boolean.typ
       Other_field.typ
       (Snarky_backendless.Typ.unit ())
       Digest.typ index)
    (let lengths =
       Commitment_lengths.of_domains_vector step_domains
       |> Dlog_marlin_types.Evals.map ~f:(Vector.reduce_exn ~f:Core.Int.max)
     in
     let t =
       Typ.tuple2
         (Dlog_marlin_types.Evals.typ ~default:Field.Constant.zero lengths
            Field.typ)
         Field.typ
     in
     Typ.tuple3 t t t)
    (Vector.typ Inner_curve.typ local_max_branching)
    (Vector.typ (Vector.typ Field.typ Rounds.n) local_max_branching)
    Wrap_proof.typ
