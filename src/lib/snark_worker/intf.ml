open Async
module Work = Snark_work_lib

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

  (**
     [perform ~state ~spec] returns a Work.Result.Partitioned.t following the
     specification [spec].The proof is created by a worker with state [state].

     We're using Stable.Latest type as we would be dealing with the internal of
     the specs/proofs, and input/output of all 3 RPCs will have to go across the
     RPC boundary. Unless we have architectural refactor, there's no point using
     cached type here.
  *)
  val perform :
       state:Worker_state.t
    -> spec:Work.Spec.Partitioned.Stable.Latest.t
    -> Work.Result.Partitioned.Stable.Latest.t Deferred.Or_error.t

  (**
     [perform_single ~state ~single_spec ~sok_message] is retained so we can
     still support old single spce, this is needed for components like
     uptime_snark_worker
  *)

  val perform_single :
       state:Worker_state.t
    -> single_spec:Work.Spec.Single.Stable.V1.t
    -> sok_message:Mina_base.Sok_message.t
    -> (Ledger_proof.Stable.Latest.t * Core_kernel.Time.Span.t)
       Deferred.Or_error.t
end
