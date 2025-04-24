open Core
open Async
module Work = Snark_work_lib

(* A worker that would only deal with one single work a time. This exists solely
   to pay off the tech debt introduced due to work partitioner distributing a
   One_or_two work.
*)
module type Single_worker = sig
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
    -> Work.Selector.Single.Spec.t
    -> (Ledger_proof.t * Time.Span.t) Deferred.Or_error.t
end
