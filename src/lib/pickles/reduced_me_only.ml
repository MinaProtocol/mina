open Zexe_backend
open Core
open Pickles_types
open Types
open Common

module Pairing_based = struct
  type ('s, 'sgs) t = {app_state: 's; sg: 'sgs}
  [@@deriving sexp, bin_io, yojson, sexp, compare]

  let prepare ~dlog_marlin_index {app_state; sg} =
    {Pairing_based.Proof_state.Me_only.app_state; sg; dlog_marlin_index}
end

module Dlog_based = struct
  module Challenges_vector = struct
    type t =
      ( Challenge.Constant.t Scalar_challenge.Stable.Latest.t
      , bool )
      Bulletproof_challenge.t
      Bp_vec.t
    [@@deriving bin_io, sexp, compare, yojson]

    module Prepared = struct
      type t = (Fq.t, Rounds.n) Vector.t
    end
  end

  type 'max_local_max_branching t =
    ( G1.Affine.t
    , G1.Affine.t Unshifted_acc.t
    , (Challenges_vector.t, 'max_local_max_branching) Vector.t )
    Dlog_based.Proof_state.Me_only.t

  module Prepared = struct
    type 'max_local_max_branching t =
      ( G1.Affine.t
      , G1.Affine.t Unshifted_acc.t
      , (Challenges_vector.Prepared.t, 'max_local_max_branching) Vector.t )
      Dlog_based.Proof_state.Me_only.t
  end

  let prepare ({pairing_marlin_acc; old_bulletproof_challenges} : _ t) =
    { Dlog_based.Proof_state.Me_only.pairing_marlin_acc
    ; old_bulletproof_challenges=
        Vector.map ~f:compute_challenges old_bulletproof_challenges }
end
