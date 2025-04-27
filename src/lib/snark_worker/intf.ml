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

  val perform :
       state:Worker_state.t
    -> spec:Work.Partitioned.Spec.t
    -> prover:Signature_lib.Public_key.Compressed.t
    -> Work.Partitioned.Result.t Deferred.Or_error.t
end
