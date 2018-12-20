open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Protocols.Coda_transition_frontier
open Coda_base

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Time : Time_intf

  module State_proof :
    Proof_intf
    with type input := Consensus.Mechanism.Protocol_state.value
     and type t := Proof.t
end

let transition_error msg = Or_error.errorf !"transition rejected :%s" msg

module Make (Inputs : Inputs_intf) :
  Protocol_state_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_with_valid_protocol_state :=
              Inputs.External_transition.With_valid_protocol_state.t = struct
  include Inputs

  let to_unix_timestamp recieved_time =
    recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
    |> Unix_timestamp.of_int64

  let to_valid_protocol_state_transition transition =
    External_transition.(
      With_valid_protocol_state.create
        ~protocol_state:(protocol_state transition)
        ~protocol_state_proof:(protocol_state_proof transition)
        ~staged_ledger_diff:(staged_ledger_diff transition))

  let validate_proof transition =
    if%map
      State_proof.verify
        (External_transition.protocol_state_proof transition)
        (External_transition.protocol_state transition)
    then Ok (to_valid_protocol_state_transition transition)
    else transition_error "proof was invalid"

  let validate_consensus_state ~time_received transition =
    let time_received = to_unix_timestamp time_received in
    let consensus_state =
      Fn.compose External_transition.Protocol_state.consensus_state
        External_transition.protocol_state
    in
    if Consensus.Mechanism.is_valid (consensus_state transition) ~time_received
    then validate_proof transition
    else Deferred.return @@ transition_error "failed consensus validation"
end
