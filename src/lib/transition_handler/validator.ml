open Async_kernel
open Core_kernel
open Pipe_lib.Strict_pipe
open Coda_base
open Cache_lib
open Protocols.Coda_transition_frontier

module Make (Inputs : Inputs.With_unprocessed_transition_cache.S) :
  Transition_handler_validator_intf
  with type time := Inputs.Time.t
   and type state_hash := State_hash.t
   and type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
   and type trust_system := Trust_system.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type staged_ledger := Inputs.Staged_ledger.t = struct
  open Inputs
  open Consensus

  let validate_transition ~logger ~frontier ~unprocessed_transition_cache
      transition_with_hash =
    let open With_hash in
    let open Protocol_state in
    let open Result.Let_syntax in
    let {hash; data= transition} =
      Envelope.Incoming.data transition_with_hash
    in
    let protocol_state =
      External_transition.Verified.protocol_state transition
    in
    let root_protocol_state =
      Transition_frontier.root frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
      |> External_transition.Verified.protocol_state
    in
    let%bind () =
      Option.fold (Transition_frontier.find frontier hash) ~init:Result.ok_unit
        ~f:(fun _ _ -> Result.Error (`In_frontier hash))
    in
    let%bind () =
      Option.fold
        (Unprocessed_transition_cache.final_state unprocessed_transition_cache
           transition_with_hash) ~init:Result.ok_unit ~f:(fun _ final_state ->
          Result.Error (`In_process final_state) )
    in
    let%map () =
      Result.ok_if_true
        ( `Take
        = Consensus.select
            ~logger:
              (Logger.extend logger
                 [("selection_context", `String "Transition_handler.Validator")])
            ~existing:(consensus_state root_protocol_state)
            ~candidate:(consensus_state protocol_state) )
        ~error:`Disconnected
    in
    (* we expect this to be Ok since we just checked the cache *)
    Unprocessed_transition_cache.register_exn unprocessed_transition_cache
      transition_with_hash

  let run ~logger ~trust_system ~frontier ~transition_reader
      ~(valid_transition_writer :
         ( ( (External_transition.Verified.t, State_hash.t) With_hash.t
             Envelope.Incoming.t
           , State_hash.t )
           Cached.t
         , crash buffered
         , unit )
         Writer.t) ~unprocessed_transition_cache =
    let module Lru = Core_extended_cache.Lru in
    let already_reported_duplicates =
      Lru.create ~destruct:None Consensus.Constants.(k * c)
    in
    don't_wait_for
      (Reader.iter transition_reader
         ~f:(fun (`Transition transition_env, `Time_received _) ->
           let (transition : External_transition.Verified.t) =
             Envelope.Incoming.data transition_env
           in
           let sender = Envelope.Incoming.sender transition_env in
           let hash =
             Protocol_state.hash
               (External_transition.Verified.protocol_state transition)
           in
           let transition_with_hash =
             Envelope.Incoming.wrap
               ~data:{With_hash.hash; data= transition}
               ~sender
           in
           match
             validate_transition ~logger ~frontier
               ~unprocessed_transition_cache transition_with_hash
           with
           | Ok cached_transition ->
               Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                 "transition $state_hash passed validation"
                 ~metadata:
                   [ ("state_hash", State_hash.to_yojson hash)
                   ; ( "transition"
                     , External_transition.Verified.to_yojson transition ) ] ;
               let transition_time =
                 External_transition.Verified.protocol_state transition
                 |> Protocol_state.blockchain_state
                 |> Blockchain_state.timestamp |> Block_time.to_time
               in
               let hist_name =
                 match sender with
                 | Envelope.Sender.Local ->
                     "accepted_transition_local_latency"
                 | Envelope.Sender.Remote _ ->
                     "accepted_transition_remote_latency"
               in
               Perf_histograms.add_span ~name:hist_name
                 (Core_kernel.Time.diff (Core_kernel.Time.now ())
                    transition_time) ;
               Writer.write valid_transition_writer cached_transition ;
               Deferred.return ()
           | Error (`In_frontier _) | Error (`In_process _) ->
               if Lru.find already_reported_duplicates hash |> Option.is_none
               then (
                 Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                   "ignoring transition we've already seen $state_hash"
                   ~metadata:
                     [ ("state_hash", State_hash.to_yojson hash)
                     ; ( "transition"
                       , External_transition.Verified.to_yojson transition ) ] ;
                 Lru.add already_reported_duplicates ~key:hash ~data:() ) ;
               Deferred.return ()
           | Error `Disconnected ->
               Trust_system.record_envelope_sender trust_system logger sender
                 ( Trust_system.Actions.Disconnected_chain
                 , Some
                     ( "received transition that was not connected to our \
                        chain from $sender"
                     , [ ( "sender"
                         , Envelope.Sender.to_yojson
                             (Envelope.Incoming.sender transition_env) )
                       ; ( "transition"
                         , External_transition.Verified.to_yojson transition )
                       ] ) ) ))
end
