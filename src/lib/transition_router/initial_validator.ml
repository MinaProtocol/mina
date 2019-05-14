open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Pipe_lib.Strict_pipe
open Coda_base
open Coda_state
open Coda_transition

type validation_error =
  [ `Invalid_time_received of [`Too_early | `Too_late of int64]
  | `Invalid_proof
  | `Verifier_error of Error.t ]

type ('time_received_valid, 'proof_valid) validation_result =
  ( ( [`Time_received] * 'time_received_valid
    , [`Proof] * 'proof_valid
    , [`Frontier_dependencies] * Truth.false_t
    , [`Staged_ledger_diff] * Truth.false_t )
    External_transition.Validation.with_transition
  , validation_error )
  Deferred.Result.t

let handle_validation_error ~logger ~trust_system ~sender ~state_hash
    (error : validation_error) =
  match error with
  | `Verifier_error err ->
      Logger.error logger ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("state_hash", State_hash.to_yojson state_hash)]
        "Error while verifying blockchain proof for $state_hash: %s"
        (Error.to_string_hum err) ;
      return ()
  | `Invalid_time_received `Too_early ->
      Trust_system.record_envelope_sender trust_system logger sender
        (Trust_system.Actions.Gossiped_future_transition, None)
  | `Invalid_time_received (`Too_late slot_diff) ->
      Trust_system.record_envelope_sender trust_system logger sender
        ( Trust_system.Actions.Gossiped_old_transition slot_diff
        , Some
            ( "off by $slot_diff slots"
            , [("slot_diff", `String (Int64.to_string slot_diff))] ) )
  | `Invalid_proof ->
      Trust_system.record_envelope_sender trust_system logger sender
        (Trust_system.Actions.Gossiped_invalid_transition, None)

let run ~logger ~trust_system ~transition_reader ~valid_transition_writer =
  let open Deferred.Let_syntax in
  Reader.iter transition_reader ~f:(fun network_transition ->
      let `Transition transition_env, `Time_received time_received =
        network_transition
      in
      let (transition : External_transition.t) =
        Envelope.Incoming.data transition_env
      in
      let sender = Envelope.Incoming.sender transition_env in
      match%map
        let open Deferred.Result.Let_syntax in
        let transition = External_transition.Validation.wrap transition in
        let%bind transition =
          ( Deferred.return
              (External_transition.validate_time_received transition
                 ~time_received)
            :> (Truth.true_t, Truth.false_t) validation_result )
        in
        ( External_transition.validate_proof transition ~verifier
          :> (Truth.true_t, Truth.true_t) validation_result )
      with
      | Ok verified_transition ->
          ( `Transition
              (Envelope.Incoming.wrap ~data:verified_transition ~sender)
          , `Time_received time_received )
          |> Writer.write valid_transition_writer ;
          return ()
      | Error () ->
          let%map () =
            handle_validation_error ~logger ~trust_system ~sender ~state_hash
              error
          in
          Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ("peer", Envelope.Sender.to_yojson sender)
              ; ("transition", External_transition.to_yojson transition) ]
            !"Failed to validate transition from $peer" )
  |> don't_wait_for
