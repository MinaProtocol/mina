open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module State_proof :
    Proof_intf
    with type input := Consensus.Protocol_state.Value.t
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
     and type consensus_local_state := Consensus.Local_state.t
     and type user_command := User_command.t
     and type diff_mutant :=
                ( External_transition.Stable.Latest.t
                , State_hash.Stable.Latest.t )
                With_hash.t
                Diff_mutant.e

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
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ("peer", Envelope.Sender.to_yojson sender)
                ; ("error", `String (Error.to_string_hum e)) ]
              !"Got an invalid transition from peer: $peer $error" )
    |> don't_wait_for
end
