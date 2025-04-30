open Async
open Core
open Snark_work_lib.Selector

module type Worker = sig
  module Worker_state : sig
    type t

    val create :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> proof_level:Genesis_constants.Proof_level.t
      -> unit
      -> t Deferred.t

    val worker_wait_time : float
  end

  (* NOTE:
     We're using Stable.Latest type as we would be dealing with the internal of
     the specs/proofs, and stuff will have to go across the RPC boundary. Unless
     we have architectural refactor, there's no point using cached type here.
  *)
  val perform :
       state:Worker_state.t
    -> spec:Spec.Stable.Latest.t
    -> sok_digest:Mina_base.Sok_message.Digest.t
    -> ( Ledger_proof.Stable.Latest.t
       * Time.Stable.Span.V1.t
       * [ `Transition | `Merge ] )
       One_or_two.Stable.V1.t
       Deferred.Or_error.t
end
