open Async_kernel
open Core_kernel
open Pipe_lib
module Timeout = Timeout_lib.Core_time

let broadcast_pipe_fold_until_with_timeout reader ~timeout_duration
    ~timeout_result ~init ~f =
  let timed_out = ref false in
  let result = ref None in
  let acc = ref init in
  let read_deferred =
    Broadcast_pipe.Reader.iter_until reader ~f:(fun msg ->
        Deferred.return
          ( if !timed_out then true
          else
            match f !acc msg with
            | `Stop x ->
                result := Some x ;
                true
            | `Continue x ->
                acc := x ;
                false ) )
  in
  match%map Timeout.await () ~timeout_duration read_deferred with
  | `Ok () ->
      Option.value_exn !result
  | `Timeout ->
      timed_out := true ;
      timeout_result

module Make (Engine : Intf.Engine.S) () :
  Intf.Dsl.S with module Engine := Engine = struct
  module Event_router = Event_router.Make (Engine) ()

  module Network_state = Network_state.Make (Engine) (Event_router)
  module Wait_condition =
    Wait_condition.Make (Engine) (Event_router) (Network_state)
  module Node = Engine.Network.Node
  module Util = Util.Make (Engine)

  (* TODO: monadify as Malleable_error w/ global value threading *)
  type t =
    { logger: Logger.t
    ; network: Engine.Network.t
    ; event_router: Event_router.t
    ; network_state_reader: Network_state.t Broadcast_pipe.Reader.t }

  let create ~logger ~network ~event_router ~network_state_reader =
    let t = {logger; network; event_router; network_state_reader} in
    `Don't_call_in_tests t

  let hard_wait_for_network_state_predicate ~logger ~hard_timeout
      ~network_state_reader ~init ~check =
    let open Wait_condition in
    let handle_predicate_result = function
      | Predicate_passed ->
          `Stop `Success
      | Predicate_failure error ->
          `Stop (`Failure error)
      | Predicate_continuation new_predicate_state ->
          `Continue new_predicate_state
    in
    let handle_network_state predicate_state network_state =
      [%log debug] "Handling network state predicate" ;
      check predicate_state network_state |> handle_predicate_result
    in
    [%log debug] "Initializing network state predicate" ;
    match
      Broadcast_pipe.Reader.peek network_state_reader
      |> init |> handle_predicate_result
    with
    | `Stop result ->
        Deferred.return result
    | `Continue init_predicate_state ->
        broadcast_pipe_fold_until_with_timeout network_state_reader
          ~timeout_duration:hard_timeout ~timeout_result:`Hard_timeout
          ~init:init_predicate_state ~f:handle_network_state

  let hard_wait_for_event_predicate ~logger ~hard_timeout ~event_router
      ~event_type ~init ~f =
    let open Wait_condition in
    let state = ref init in
    let handle_event node data =
      [%log debug] "Handling event predicate" ;
      Deferred.return
        ( match f !state node data with
        | Predicate_passed ->
            `Stop `Success
        | Predicate_failure err ->
            `Stop (`Failure err)
        | Predicate_continuation new_state ->
            state := new_state ;
            `Continue )
    in
    Event_router.on event_router event_type ~f:handle_event
    |> Event_router.await_with_timeout event_router
         ~timeout_duration:hard_timeout ~timeout_cancellation:`Hard_timeout

  let wait_for t condition =
    let open Wait_condition in
    let constants = Engine.Network.constants t.network in
    let soft_timeout =
      Network_time_span.to_span condition.soft_timeout ~constants
    in
    let hard_timeout =
      Network_time_span.to_span condition.hard_timeout ~constants
    in
    let start_time = Time.now () in
    [%log' info t.logger]
      "Waiting for %s (soft_timeout: $soft_timeout, hard_timeout: \
       $hard_timeout)"
      condition.description
      ~metadata:
        [ ( "soft_timeout"
          , `String
              (Network_time_span.to_string ~constants condition.soft_timeout)
          )
        ; ( "hard_timeout"
          , `String
              (Network_time_span.to_string ~constants condition.hard_timeout)
          ) ] ;
    let%bind result =
      match condition.predicate with
      | Network_state_predicate (init, check) ->
          hard_wait_for_network_state_predicate ~logger:t.logger
            ~network_state_reader:t.network_state_reader ~hard_timeout ~init
            ~check
      | Event_predicate (event_type, init, f) ->
          hard_wait_for_event_predicate ~logger:t.logger
            ~event_router:t.event_router ~hard_timeout ~event_type ~init ~f
    in
    match result with
    | `Hard_timeout ->
        Malleable_error.of_string_hard_error_format
          "hit a hard timeout waiting for %s" condition.description
    | `Failure error ->
        Malleable_error.of_error_hard
          (Error.of_list
             [ Error.createf "wait_for hit an error waiting for %s"
                 condition.description
             ; error ])
    | `Success ->
        let soft_timeout_was_met =
          Time.(add start_time soft_timeout >= now ())
        in
        if soft_timeout_was_met then (
          [%log' info t.logger] "Finished waiting for %s" condition.description ;
          Malleable_error.return () )
        else
          Error.createf
            "wait_for hit a soft timeout waiting for %s (condition succeeded, \
             but beyond expectation)"
            condition.description
          |> Malleable_error.soft_error ()

  (**************************************************************************************************)
  (* TODO: move into executive module *)

  type log_error = Node.t * Event_type.Log_error.t

  type error_accumulator =
    { warn: log_error DynArray.t
    ; error: log_error DynArray.t
    ; faulty_peer: log_error DynArray.t
    ; fatal: log_error DynArray.t }

  let empty_error_accumulator () =
    { warn= DynArray.create ()
    ; error= DynArray.create ()
    ; faulty_peer= DynArray.create ()
    ; fatal= DynArray.create () }

  let watch_log_errors ~logger ~event_router ~on_fatal_error =
    let error_accumulator = empty_error_accumulator () in
    ignore
      (Event_router.on event_router Event_type.Log_error
         ~f:(fun node message ->
           let open Logger.Message in
           let acc =
             match message.level with
             | Warn ->
                 error_accumulator.warn
             | Error ->
                 error_accumulator.error
             | Faulty_peer ->
                 error_accumulator.faulty_peer
             | Fatal ->
                 error_accumulator.fatal
             | _ ->
                 failwith "unexpected log level encountered"
           in
           DynArray.add acc (node, message) ;
           if message.level = Fatal then (
             [%log fatal] "Error occured $error"
               ~metadata:[("error", Logger.Message.to_yojson message)] ;
             on_fatal_error message ) ;
           Deferred.return `Continue )) ;
    error_accumulator

  let lift_accumulated_errors error_accumulator =
    let lift error_array =
      DynArray.to_list error_array
      |> List.map ~f:(fun (node, message) ->
             Test_error.Remote_error
               {node_id= Node.id node; error_message= message} )
    in
    let soft_errors =
      lift error_accumulator.warn @ lift error_accumulator.faulty_peer
    in
    let hard_errors =
      lift error_accumulator.error @ lift error_accumulator.fatal
    in
    {Test_error.Set.soft_errors; hard_errors}
end
