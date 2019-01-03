open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module State_proof :
    Proof_intf
    with type input := Consensus.Mechanism.Protocol_state.value
     and type t := Proof.t

  module Time : Time_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type masked_ledger := Coda_base.Ledger.t

  module Protocol_state_validator :
    Protocol_state_validator_intf
    with type time := Time.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_proof_verified :=
                External_transition.Proof_verified.t
     and type external_transition_verified := External_transition.Verified.t
end

module Make (Inputs : Inputs_intf) :
  Protocols.Coda_transition_frontier.Initial_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t = struct
  open Inputs

  let run ~logger ~transition_reader ~valid_transition_writer =
    let logger = Logger.child logger __MODULE__ in
    Reader.iter transition_reader ~f:(fun network_transition ->
        let `Transition transition_env, `Time_received time_received =
          network_transition
        in
        let (transition : External_transition.t) =
          Envelope.Incoming.data transition_env
        in
        let sender = Envelope.Incoming.sender transition_env in
        match%map
          Protocol_state_validator.validate_consensus_state ~time_received
            transition
        with
        | Ok verified_transition ->
            ( `Transition
                (Envelope.Incoming.wrap ~data:verified_transition ~sender)
            , `Time_received time_received )
            |> Writer.write valid_transition_writer
        | Error e ->
            Logger.warn logger
              !"Got an invalid transition from peer : %{sexp:Host_and_port.t} \
                %{sexp:Error.t}"
              sender e )
    |> don't_wait_for
end
