open Core_kernel
open Async_kernel
open Pipe_lib.Strict_pipe
open Coda_base
open Coda_state
open Signature_lib

module Make (Inputs : Transition_frontier.Inputs_intf) = struct
  open Inputs

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
    let open Trust_system.Actions in
    let punish action message =
      Trust_system.record_envelope_sender trust_system logger sender
        (action, message)
    in
    match error with
    | `Verifier_error err ->
        let error_metadata = [("error", `String (Error.to_string_hum err))] in
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            (error_metadata @ [("state_hash", State_hash.to_yojson state_hash)])
          "Error while verifying blockchain proof for $state_hash: $error" ;
        punish Sent_invalid_proof (Some ("verifier error", error_metadata))
    | `Invalid_proof ->
        punish Sent_invalid_proof None
    | `Invalid_time_received `Too_early ->
        punish Gossiped_future_transition None
    | `Invalid_time_received (`Too_late slot_diff) ->
        punish (Gossiped_old_transition slot_diff)
          (Some
             ( "off by $slot_diff slots"
             , [("slot_diff", `String (Int64.to_string slot_diff))] ))

  module Duplicate_proposal_detector = struct
    module T = struct
      (* int is a slot *)
      type t = Public_key.Compressed.Stable.V1.t * int
      [@@deriving bin_io, sexp, hash, compare]
    end

    module Key = Hashable.Make_binable (T)

    type t = {table: State_hash.t Key.Table.t; mutable latest_epoch: int}

    let create () = {table= Key.Table.create (); latest_epoch= 0}

    let check t logger external_transition_with_hash =
      let external_transition = external_transition_with_hash.With_hash.data in
      let protocol_state_hash = external_transition_with_hash.hash in
      let open Consensus.Data.Consensus_state in
      let consensus_state =
        External_transition.consensus_state external_transition
      in
      match curr_epoch_and_slot_opt consensus_state with
      | None ->
          ()
      | Some (epoch, slot) -> (
          (* new epoch, flush table *)
          (* TODO: can we see transitions from previous epochs *)
          if epoch > t.latest_epoch then (
            Key.Table.clear t.table ;
            t.latest_epoch <- epoch ) ;
          let proposer = External_transition.proposer external_transition in
          let key = (proposer, slot) in
          match Key.Table.find t.table key with
          | None ->
              Key.Table.add_exn t.table ~key ~data:protocol_state_hash
          | Some hash ->
              if not (State_hash.equal hash protocol_state_hash) then
                Logger.error logger ~module_:__MODULE__ ~location:__LOC__
                  !"Duplicate proposer and slot: proposer = %{sexp: \
                    Public_key.Compressed.t}, slot = %i, previous protocol \
                    state hash = %s, current protocol state hash = %s"
                  proposer slot (State_hash.to_bytes hash)
                  (State_hash.to_bytes protocol_state_hash) )
  end

  let run ~logger ~trust_system ~verifier ~transition_reader
      ~valid_transition_writer =
    let open Deferred.Let_syntax in
    let duplicate_checker = Duplicate_proposal_detector.create () in
    Reader.iter transition_reader ~f:(fun network_transition ->
        let `Transition transition_env, `Time_received time_received =
          network_transition
        in
        let transition_with_hash =
          Envelope.Incoming.data transition_env
          |> With_hash.of_data
               ~hash_data:
                 (Fn.compose Protocol_state.hash
                    External_transition.protocol_state)
        in
        Duplicate_proposal_detector.check duplicate_checker logger
          transition_with_hash ;
        let sender = Envelope.Incoming.sender transition_env in
        match%bind
          let open Deferred.Result.Let_syntax in
          let transition =
            External_transition.Validation.wrap transition_with_hash
          in
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
        | Error error ->
            let%map () =
              handle_validation_error ~logger ~trust_system ~sender
                ~state_hash:(With_hash.hash transition_with_hash)
                error
            in
            Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ("peer", Envelope.Sender.to_yojson sender)
                ; ( "transition"
                  , External_transition.to_yojson
                      (With_hash.data transition_with_hash) ) ]
              !"Failed to validate transition from $peer" )
    |> don't_wait_for
end
