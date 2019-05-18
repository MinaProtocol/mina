open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Network : sig
    type t
  end

  module Transition_frontier :
    Protocols.Coda_transition_frontier.Transition_frontier_intf
    with type state_hash := State_hash.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type external_transition_validated := External_transition.Validated.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type user_command := User_command.t
     and type pending_coinbase := Pending_coinbase.t
     and type consensus_state := Consensus.Data.Consensus_state.Value.t
     and type consensus_local_state := Consensus.Data.Local_state.t
     and type verifier := Verifier.t
     and module Extensions.Work = Transaction_snark_work.Statement

  module Transition_frontier_controller :
    Protocols.Coda_transition_frontier.Transition_frontier_controller_intf
    with type time_controller := Block_time.Controller.t
     and type external_transition_validated := External_transition.Validated.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type state_hash := State_hash.t
     and type transition_frontier := Transition_frontier.t
     and type breadcrumb := Transition_frontier.Breadcrumb.t
     and type network := Network.t
     and type verifier := Verifier.t
     and type time := Block_time.t

  module Bootstrap_controller :
    Protocols.Coda_transition_frontier.Bootstrap_controller_intf
    with type time := Block_time.t
     and type network := Network.t
     and type verifier := Verifier.t
     and type transition_frontier := Transition_frontier.t
     and type external_transition_with_initial_validation :=
                External_transition.with_initial_validation
     and type ledger_db := Ledger.Db.t
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
    -> (External_transition.Validated.t, State_hash.t) With_hash.t
       Strict_pipe.Reader.t
end
