(** SNARK Worker Library

    This library provides infrastructure for SNARK workers that generate
    zero-knowledge proofs for transactions in the Mina protocol. SNARK workers
    are external processes that connect to a Mina daemon, receive work
    specifications, generate SNARK proofs, and submit the results back to the
    daemon.

    The library includes:
    - A modular interface for different worker implementations
    - RPC definitions for communication with the daemon
    - Entry points for running SNARK worker processes
    - Utilities for proof generation, caching, and error handling

    @see <https://docs.minaprotocol.com/mina-protocol/snark-workers> SNARK Workers
    documentation
*)

(** Module for CLI and process entry points *)
module Entry : sig
  (** Main entry point for the SNARK worker process *)
  val main :
       logger:Logger.t
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Core.Host_and_port.t
    -> bool
    -> unit Async.Deferred.t

  (** Create a command for the SNARK worker with RPC-based communication *)
  val command_from_rpcs :
       commit_id:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> Core.Command.t

  (** Generate command-line arguments for running a SNARK worker *)
  val arguments :
       proof_level:Genesis_constants.Proof_level.t
    -> daemon_address:Core.Host_and_port.t
    -> shutdown_on_disconnect:bool
    -> string list
end

(** Module providing versioned RPCs for worker-daemon communication *)
module Rpcs : sig
  (** RPC for requesting work from the daemon *)
  module Get_work : module type of Rpc_get_work

  (** RPC for submitting completed SNARK proofs to the daemon *)
  module Submit_work : module type of Rpc_submit_work

  (** RPC for reporting failures in SNARK proof generation *)
  module Failed_to_generate_snark : module type of Rpc_failed_to_generate_snark
end

(** Module providing worker implementations *)
module Worker : sig
  (** Debug implementation for testing and development *)
  module Debug : Intf.Worker

  (** Production implementation for generating actual SNARK proofs *)
  module Prod : Intf.Worker
end

(** Module containing structured logging events *)
module Events : module type of Events
