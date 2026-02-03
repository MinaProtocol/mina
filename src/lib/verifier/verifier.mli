(** Transaction and SNARK verification for the Mina protocol.

    {2 Architecture}

    The production verifier ([Prod]) runs as a separate child process spawned via
    [Rpc_parallel] (Jane Street library). This isolates CPU-intensive SNARK
    verification from the main daemon.

    {b Process structure} (see [prod.ml]):
    - [Worker.T]: Defines RPC functions and worker state
    - [Rpc_parallel.Make(T)]: Generates spawn/connection machinery
    - [Worker.spawn_in_foreground_exn]: Spawns verifier process
    - [Worker.Connection.run]: Calls RPC functions on worker

    {b Daemon integration} (see [Mina_lib.create]):
    - Created at daemon startup with verification keys from prover
    - Stored in [processes.verifier]
    - Passed to: [Block_producer], [Transaction_pool], [Snark_pool], [Transition_frontier]

    {2 Verification Types}

    - {b Commands}: Verifies signatures and proofs on user commands
    - {b Blockchain SNARKs}: Verifies protocol state transition proofs
      (consensus layer)
    - {b Transaction SNARKs}: Verifies ledger transition proofs (execution
      layer)

    {2 Implementations}

    - {b Prod}: Separate process via [Rpc_parallel] (prod.ml)
    - {b Dummy}: Accepts all inputs without verification (for tests)

    {2 Common Module}

    Core verification logic used outside the verifier process:
    - [check_signatures_of_zkapp_command]: Verifies zkApp signatures
    - [check_signed_command]: Verifies signed command signatures
*)

module Common : module type of Common

module Failure = Verification_failure

module Dummy : module type of Dummy

module Prod : module type of Prod

include Verifier_intf.S with type ledger_proof = Ledger_proof.t

val get_verification_keys_eagerly :
     signature_kind:Mina_signature_kind.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> ( [ `Blockchain of Pickles.Verification_key.t ]
     * [ `Transaction of Pickles.Verification_key.t ] )
     Async.Deferred.t

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
