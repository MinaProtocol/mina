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
     [perform ~state ~spec ~sok_digest] returns a [One_or_two.t] of triple
     ([proof], [time_elapsed], [tag]) following the specification [spec] with
     digest [sok_digest]. The proof is created by a worker with state [state].

     The [tag] is used to indicate what kind of specification is provided, and
     is used when logging metrics. ['a One_or_two.t] is leaky abstraction due to
     the fact that a Work Selector issue 1 or 2 specs, and that has been encoded
     in old RPCs in this library. And there's no way to get rid of them without
     sacrificing compatibility.

     We're using Stable.Latest type as we would be dealing with the internal of
     the specs/proofs, and input/output of all 3 RPCs will have to go across the
     RPC boundary. Unless we have architectural refactor, there's no point using
     cached type here.
  *)
  val perform :
       state:Worker_state.t
    -> spec:Work.Spec.Partitioned.Stable.Latest.t
    -> Work.Result.Partitioned.Stable.Latest.t Deferred.Or_error.t
end
