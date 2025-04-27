open Async
open Snark_work_lib.Partitioned

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

  val perform :
       state:Worker_state.t
    -> spec:Spec.t
    -> sok_digest:Mina_base.Sok_message.Digest.t
    -> Proof_with_metric.t Spec.Poly.t Deferred.Or_error.t
end
