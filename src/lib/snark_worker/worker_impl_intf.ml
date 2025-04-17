open Async
open Core_kernel

module type Worker_impl = sig
  module Worker_state : sig
    type t

    val create :
         constraint_constants:Genesis_constants.Constraint_constants.t
      -> proof_level:Genesis_constants.Proof_level.t
      -> unit
      -> t Deferred.t

    val worker_wait_time : float
  end

  val perform_single :
       Worker_state.t
    -> message:Mina_base.Sok_message.t
    -> Snark_work_lib.Wire.Single.Spec.t
    -> (Ledger_proof.t * Time.Span.t) Deferred.Or_error.t
end
