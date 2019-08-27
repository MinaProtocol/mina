open Async_kernel
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Network : sig
    type t

    val high_connectivity : t -> unit Ivar.t

    val peers : t -> Network_peer.Peer.t list
  end

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * unit Truth.true_t
                , [`Proof] * unit Truth.true_t
                , [`Delta_transition_chain]
                  * State_hash.t Non_empty_list.t Truth.true_t
                , [`Frontier_dependencies] * unit Truth.true_t
                , [`Staged_ledger_diff] * unit Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t

  module Transition_frontier_controller :
    Coda_intf.Transition_frontier_controller_intf
    with type external_transition_validated := External_transition.Validated.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Network.t
     and type verifier := Verifier.t

  module Bootstrap_controller :
    Coda_intf.Bootstrap_controller_intf
    with type network := Network.t
     and type verifier := Verifier.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
end

module Make (Inputs : Inputs_intf) : sig
  open Inputs

  val run :
       logger:Logger.t
    -> trust_system:Trust_system.t
    -> verifier:Verifier.t
    -> network:Network.t
    -> time_controller:Block_time.Controller.t
    -> frontier_broadcast_pipe:Transition_frontier.t option
                               Broadcast_pipe.Reader.t
                               * Transition_frontier.t option
                                 Broadcast_pipe.Writer.t
    -> ledger_db:Ledger.Db.t
    -> network_transition_reader:( [ `Transition of
                                     External_transition.t Envelope.Incoming.t
                                   ]
                                 * [`Time_received of Block_time.t] )
                                 Strict_pipe.Reader.t
    -> proposer_transition_reader:Transition_frontier.Breadcrumb.t
                                  Strict_pipe.Reader.t
    -> most_recent_valid_block:External_transition.t Broadcast_pipe.Reader.t
                               * External_transition.t Broadcast_pipe.Writer.t
    -> Transition_frontier.t
    -> External_transition.Validated.t Strict_pipe.Reader.t
end

open Coda_transition

val run :
     logger:Logger.t
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Coda_networking.t
  -> time_controller:Block_time.Controller.t
  -> frontier_broadcast_pipe:Transition_frontier.t option
                             Broadcast_pipe.Reader.t
                             * Transition_frontier.t option
                               Broadcast_pipe.Writer.t
  -> ledger_db:Ledger.Db.t
  -> network_transition_reader:( [ `Transition of
                                   External_transition.t Envelope.Incoming.t ]
                               * [`Time_received of Block_time.t] )
                               Strict_pipe.Reader.t
  -> proposer_transition_reader:Transition_frontier.Breadcrumb.t
                                Strict_pipe.Reader.t
  -> most_recent_valid_block:External_transition.t Broadcast_pipe.Reader.t
                             * External_transition.t Broadcast_pipe.Writer.t
  -> Transition_frontier.t
  -> External_transition.Validated.t Strict_pipe.Reader.t
