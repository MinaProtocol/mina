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
    with type input := Consensus.Protocol_state.Value.t
     and type t := Proof.t
end

let transition_error msg = Or_error.errorf "transition rejected: %s" msg

module Make (Inputs : Inputs_intf) :
  Protocol_state_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition := Consensus.External_transition.t
   and type external_transition_proof_verified :=
              Consensus.External_transition.Proof_verified.t
   and type external_transition_verified :=
              Consensus.External_transition.Verified.t = struct
  include Inputs

  let to_unix_timestamp recieved_time =
    recieved_time |> Time.to_span_since_epoch |> Time.Span.to_ms
    |> Unix_timestamp.of_int64

  let validate_proof transition =
    if%map
      State_proof.verify
        (Consensus.External_transition.protocol_state_proof transition)
        (Consensus.External_transition.protocol_state transition)
    then
      (* Verified the protocol_state proof *)
      let (`I_swear_this_is_safe_see_my_comment proof_verified_transition) =
        Consensus.External_transition.to_proof_verified transition
      in
      Ok proof_verified_transition
    else transition_error "proof was invalid"

  let validate_consensus_state ~time_received transition =
    let time_received = to_unix_timestamp time_received in
    let consensus_state =
      Fn.compose Consensus.External_transition.Protocol_state.consensus_state
        Consensus.External_transition.protocol_state
    in
    if
      Consensus.received_at_valid_time
        (consensus_state transition)
        ~time_received
    then
      let open Deferred.Or_error.Let_syntax in
      let%map _ : Consensus.External_transition.Proof_verified.t =
        validate_proof transition
      in
      (* Verified both protocol_state proof and consensus_state *)
      let (`I_swear_this_is_safe_see_my_comment verified_transition) =
        Consensus.External_transition.to_verified transition
      in
      verified_transition
    else
      Deferred.return
      @@ transition_error
           (sprintf
              !"not received_at_valid_time (received at \
                %{sexp:Unix_timestamp.t}"
              time_received)
end
