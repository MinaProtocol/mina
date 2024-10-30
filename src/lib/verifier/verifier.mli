module Failure = Verification_failure

module Dummy : module type of Dummy

module Prod : module type of Prod

include Verifier_intf.S with type ledger_proof = Ledger_proof.t

module For_tests : sig
  val default :
       logger:Logger.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> ?enable_internal_tracing:bool
    -> ?internal_trace_filename:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> ?pids:Child_processes.Termination.t
    -> ?conf_dir:string option
    -> ?commit_id:string
    -> unit
    -> t Async.Deferred.t
end
