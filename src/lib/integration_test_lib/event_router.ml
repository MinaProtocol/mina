open Async_kernel
open Core_kernel
module Timeout = Timeout_lib.Core_time

module Make (Engine : Intf.Engine.S) () :
  Intf.Dsl.Event_router_intf with module Engine := Engine = struct
  module Node = Engine.Network.Node

  module Event_handler_id = Unique_id.Int ()

  type ('a, 'b) handler_func =
    Node.t -> 'a -> [ `Stop of 'b | `Continue ] Deferred.t

  type event_handler =
    | Event_handler :
        Event_handler_id.t * 'b Ivar.t * 'a Event_type.t * ('a, 'b) handler_func
        -> event_handler

  (* event subscriptions surface information from the handler (as type witnesses), but do not existentially hide the result parameter *)
  type _ event_subscription =
    | Event_subscription :
        Event_handler_id.t * 'b Ivar.t * 'a Event_type.t
        -> 'b event_subscription

  type handler_map = event_handler list Event_type.Map.t

  (* TODO: asynchronously unregistered event handlers *)
  type t = { logger : Logger.t; handlers : handler_map ref }

  let unregister_event_handlers_by_id handlers event_type ids =
    handlers :=
      Event_type.Map.update !handlers event_type ~f:(fun registered_handlers ->
          registered_handlers |> Option.value ~default:[]
          |> List.filter ~f:(fun (Event_handler (registered_id, _, _, _)) ->
                 not (List.mem ids registered_id ~equal:Event_handler_id.equal) ) )

  let dispatch_event handlers node event =
    let open Event_type in
    let open Deferred.Let_syntax in
    let event_handlers =
      Map.find !handlers (type_of_event event) |> Option.value ~default:[]
    in
    (* This loop cannot directly mutate or recompute the handlers. Doing so will introduce a race condition. *)
    let%map ids_to_remove =
      Deferred.List.filter_map ~how:`Parallel event_handlers ~f:(fun handler ->
          (* assuming the dispatch for `f` is already parallel, and not the execution of the deferred it returns *)
          let (Event (event_type, event_data)) = event in
          let (Event_handler
                ( handler_id
                , handler_finished_ivar
                , handler_type
                , handler_callback ) ) =
            handler
          in
          match%map
            dispatch_exn event_type event_data handler_type
              (handler_callback node)
          with
          | `Continue ->
              None
          | `Stop result ->
              Ivar.fill handler_finished_ivar result ;
              Some handler_id )
    in
    unregister_event_handlers_by_id handlers
      (Event_type.type_of_event event)
      ids_to_remove

  let create ~logger ~event_reader =
    let handlers = ref Event_type.Map.empty in
    don't_wait_for
      (Pipe.iter event_reader ~f:(fun (node, event) ->
           [%log debug] "Dispatching event $event for $node"
             ~metadata:
               [ ("event", Event_type.event_to_yojson event)
               ; ("node", `String (Node.id node))
               ] ;
           dispatch_event handlers node event ) ) ;
    { logger; handlers }

  let on t event_type ~f =
    let event_type_ex = Event_type.Event_type event_type in
    let handler_id = Event_handler_id.create () in
    let finished_ivar = Ivar.create () in
    let handler = Event_handler (handler_id, finished_ivar, event_type, f) in
    t.handlers :=
      Event_type.Map.add_multi !(t.handlers) ~key:event_type_ex ~data:handler ;
    Event_subscription (handler_id, finished_ivar, event_type)

  (* TODO: On cancellation, should we notify active subscriptions? Would involve changing await type to option or result. *)
  let cancel t event_subscription cancellation =
    let (Event_subscription (id, ivar, event_type)) = event_subscription in
    unregister_event_handlers_by_id t.handlers
      (Event_type.Event_type event_type) [ id ] ;
    Ivar.fill ivar cancellation

  let await event_subscription =
    let (Event_subscription (_, ivar, _)) = event_subscription in
    Ivar.read ivar

  let await_with_timeout t event_subscription ~timeout_duration
      ~timeout_cancellation =
    let open Deferred.Let_syntax in
    match%map Timeout.await () ~timeout_duration (await event_subscription) with
    | `Ok x ->
        x
    | `Timeout ->
        cancel t event_subscription timeout_cancellation ;
        timeout_cancellation
end
