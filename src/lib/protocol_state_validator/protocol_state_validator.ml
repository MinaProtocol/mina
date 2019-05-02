open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Protocols.Coda_transition_frontier
open Coda_base
open Coda_state

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Time : Time_intf

  module State_proof :
    Proof_intf with type input := Protocol_state.Value.t and type t := Proof.t
end

module Make (Inputs : Inputs_intf) :
  Protocol_state_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type external_transition_proof_verified :=
              Inputs.External_transition.Proof_verified.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type trust_system := Trust_system.t
   and type envelope_sender := Envelope.Sender.t = struct
  include Inputs

  type validation_error = [`Too_early | `Too_late of int64 | `Invalid_proof]

  type 'a validation_result = ('a, validation_error) Result.t

  let to_unix_timestamp recieved_time =
    recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
    |> Unix_timestamp.of_int64

  let validate_proof transition =
    if%map
      State_proof.verify
        (External_transition.protocol_state_proof transition)
        (External_transition.protocol_state transition)
    then
      (* Verified the protocol_state proof *)
      let (`I_swear_this_is_safe_see_my_comment proof_verified_transition) =
        External_transition.to_proof_verified transition
      in
      Ok proof_verified_transition
    else Error `Invalid_proof

  let handle_validation_error ~logger ~trust_system ~sender error =
    match error with
    | `Invalid_proof ->
        Trust_system.record_envelope_sender trust_system logger sender
          (Trust_system.Actions.Gossiped_invalid_transition, None)
    | `Too_early ->
        Trust_system.record_envelope_sender trust_system logger sender
          (Trust_system.Actions.Gossiped_future_transition, None)
    | `Too_late slot_diff ->
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_old_transition slot_diff
          , Some
              ( "off by $slot_diff slots"
              , [("slot_diff", `String (Int64.to_string slot_diff))] ) )

  let validate_consensus_state ~logger ~trust_system ~time_received ~sender
      transition =
    let time_received = to_unix_timestamp time_received in
    let consensus_state =
      External_transition.protocol_state transition
      |> Protocol_state.consensus_state
    in
    let open Deferred.Let_syntax in
    let%bind result =
      let open Deferred.Result.Let_syntax in
      let%bind () =
        Deferred.return
          ( Consensus.Hooks.received_at_valid_time consensus_state ~time_received
            :> unit validation_result )
      in
      validate_proof transition
    in
    match result with
    | Ok _ ->
        (* Verified both protocol_state proof and consensus_state *)
        let (`I_swear_this_is_safe_see_my_comment verified_transition) =
          External_transition.to_verified transition
        in
        Deferred.return (Ok verified_transition)
    | Error error ->
        handle_validation_error ~logger ~trust_system ~sender error
        >>| Fn.const (Error ())
end
