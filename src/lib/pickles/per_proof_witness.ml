open Pickles_types
module Impl = Impls.Pairing_based
module One_hot_vector = One_hot_vector.Make (Impl)

type ('local_statement, 'local_max_branching, 'local_num_branches) t =
  'local_statement
  * 'local_num_branches One_hot_vector.t
  * ( Challenge.Make(Impl).t
    , Challenge.Make(Impl).t Scalar_challenge.t
    , Pairing_main.Make(Pairing_main_inputs).Fp.t
    , Impl.Boolean.var
    , Pairing_main.Make(Pairing_main_inputs).Fq.t
    , unit
    , Digest.Make(Impl).t )
    Types.Dlog_based.Proof_state.t
  * (Impl.Field.t Pairing_marlin_types.Evals.t * Impl.Field.t)
  * (Pairing_main_inputs.G.t, 'local_max_branching) Vector.t
  * Dlog_proof.var

module Constant = struct
  open Zexe_backend

  type ('local_statement, 'local_max_branching, _) t =
    'local_statement
    * One_hot_vector.Constant.t
    * ( Challenge.Constant.t
      , Challenge.Constant.t Scalar_challenge.t
      , Fp.t
      , bool
      , Fq.t
      , unit
      , Digest.Constant.t )
      Types.Dlog_based.Proof_state.t
    * (Fp.t Pairing_marlin_types.Evals.t * Fp.t)
    * (G.Affine.t, 'local_max_branching) Vector.t
    * Dlog_proof.t
end

let typ (type n avar aval m)
    (statement : (avar, aval) Impls.Pairing_based.Typ.t)
    (local_max_branching : n Nat.t) (local_branches : m Nat.t) :
    ((avar, n, m) t, (aval, n, m) Constant.t) Impls.Pairing_based.Typ.t =
  let open Impls.Pairing_based in
  let open Pairing_main_inputs in
  let open Pairing_main in
  Snarky.Typ.tuple6 statement
    (One_hot_vector.typ local_branches)
    (Types.Dlog_based.Proof_state.typ Challenge.typ Fp.typ Boolean.typ Fq.typ
       (Snarky.Typ.unit ()) Digest.typ)
    (Typ.tuple2 (Pairing_marlin_types.Evals.typ Field.typ) Field.typ)
    (Vector.typ G.typ local_max_branching)
    Dlog_proof.typ
