open Async
open Core

type 'state msg_processed = MNext of 'state | MExit | MUnprocessed

type ('state, 'response) req_processed =
  | RNext of ('state * 'response)
  | RExit of 'response
  | RUnprocessed

type (_, _, _, _) overflow_behavior =
  | Throw : ('state, 'data, unit Or_error.t, [ `Throw ]) overflow_behavior
  | Drop_head :
      [ `Warns | `No_warns ]
      -> ('state, 'data, unit, [ `Drop_head ]) overflow_behavior
  | Drop_and_call_head :
      ('state -> 'data -> 'returns)
      -> ( 'state
         , 'data
         , 'returns option
         , [ `Drop_and_call_head ] )
         overflow_behavior
  | Push_back
      : ('state, 'data, unit Deferred.t, [ `Push_back ]) overflow_behavior

type (_, _, _, _) channel_type =
  | Infinity : ('state, 'data, unit, [ `Infinity ]) channel_type
  | With_capacity :
      [ `Capacity of int ]
      * [ `Overflow of ('state, 'data, 'returns, 'behavior) overflow_behavior ]
      -> ('state, 'data, 'returns, 'behavior) channel_type

module DummyMessage = struct
  type t = unit [@@deriving to_yojson]

  let handler ~state ~message:() = Deferred.return (MNext state)
end

module DummyRequest = struct
  type _ t = Nothing : unit t

  let handler :
      type response.
         state:'state
      -> request:response t
      -> ('state, response) req_processed Deferred.t =
   fun ~state ~request:Nothing -> Deferred.return (RNext (state, ()))
end

module WithRequest (DataMessage : sig
  type t

  val to_yojson : t -> Yojson.Safe.t
end) (Request : sig
  type _ t
end) =
struct
  exception
    ActorDataInboxOverflow of
      { name : Yojson.Safe.t; capacity : int; attempt_enqueing : DataMessage.t }

  exception RunningActorSpawned of { name : Yojson.Safe.t }

  type 'state request_handler =
    { f :
        'response.
           state:'state
        -> request:'response Request.t
        -> ('state, 'response) req_processed Deferred.t
    }

  type request_e = EReq : 'response Request.t * 'response Ivar.t -> request_e

  type ('data_returns, 'data_overflew, 'control_msg, 'state) t =
    { name : Yojson.Safe.t
    ; request_inbox : request_e Deque.t
    ; request_handler : 'state request_handler
    ; control_inbox : 'control_msg Deque.t
    ; control_handler :
        state:'state -> message:'control_msg -> 'state msg_processed Deferred.t
    ; data_inbox : DataMessage.t Deque.t
    ; data_channel_type :
        ('state, DataMessage.t, 'data_returns, 'data_overflew) channel_type
    ; data_handler :
        state:'state -> message:DataMessage.t -> 'state msg_processed Deferred.t
    ; logger : Logger.t
    ; mutable is_running : bool
    ; mutable state : 'state
    }

  let create ~name ~data_channel_type ~request_handler ~control_handler
      ~data_handler ~logger ~state =
    { name
    ; request_inbox = Deque.create ()
    ; control_inbox = Deque.create ()
    ; data_inbox = Deque.create ()
    ; data_channel_type
    ; data_handler
    ; control_handler
    ; request_handler
    ; logger
    ; is_running = false
    ; state
    }

  let terminate ~(actor : _ t) = actor.is_running <- false

  let send_request :
      type response.
      actor:_ t -> request:response Request.t -> response Deferred.t =
   fun ~actor ~request ->
    let response = Ivar.create () in
    Deque.enqueue_back actor.request_inbox (EReq (request, response)) ;
    Ivar.read response

  let send_control ~(actor : _ t) ~message =
    Deque.enqueue_back actor.control_inbox message

  let send_data :
      type data_returns data_overflew.
         actor:(data_returns, data_overflew, _, _) t
      -> message:DataMessage.t
      -> data_returns =
   fun ~actor ~message ->
    match actor.data_channel_type with
    | Infinity ->
        Deque.enqueue_back actor.data_inbox message
    | With_capacity (`Capacity capacity, `Overflow Push_back) ->
        let open Deferred.Let_syntax in
        let rec wait_then_enqueue () =
          if Deque.length actor.data_inbox >= capacity then
            let%bind () = Async.Scheduler.yield () in
            wait_then_enqueue ()
          else (
            Deque.enqueue_back actor.data_inbox message ;
            Deferred.return () )
        in
        wait_then_enqueue ()
    | With_capacity (`Capacity capacity, `Overflow Throw) ->
        if Deque.length actor.data_inbox >= capacity then
          Or_error.of_exn
            (ActorDataInboxOverflow
               { name = actor.name; capacity; attempt_enqueing = message } )
        else Ok ()
    | With_capacity (`Capacity capacity, `Overflow (Drop_head warns_or_not))
      -> (
        (* NOTE: always enqueue first to deal with capacity 0/negative *)
        Deque.enqueue_back actor.data_inbox message ;
        if Deque.length actor.data_inbox > capacity then
          let dropped = Deque.dequeue_front_exn actor.data_inbox in
          match warns_or_not with
          | `Warns ->
              let logger = actor.logger in
              [%log info]
                "Actor $actor_id has data inbox capacity %d, dropping head \
                 message $message"
                capacity
                ~metadata:
                  [ ("actor_id", actor.name)
                  ; ("message", DataMessage.to_yojson dropped)
                  ; ("capacity", `Int capacity)
                  ]
          | `No_warns ->
              () )
    | With_capacity (`Capacity cap, `Overflow (Drop_and_call_head callback)) ->
        (* NOTE: always enqueue first to deal with capacity 0/negative *)
        Deque.enqueue_back actor.data_inbox message ;

        if Deque.length actor.data_inbox > cap then
          let head = Deque.dequeue_front_exn actor.data_inbox in
          Some (callback actor.state head)
        else None

  type process_status = Status_processed | Status_fallthrough | Status_exit

  let spawn (actor : _ t) : unit Deferred.Or_error.t =
    let process_msg ~state ~deque ~handler () =
      match Deque.dequeue_front deque with
      | Some message -> (
          match%map handler ~state ~message with
          | MUnprocessed ->
              Deque.enqueue_front deque message ;
              MUnprocessed
          | result ->
              result )
      | None ->
          Deferred.return MUnprocessed
    in
    let process_request ~state ~(deque : request_e Deque.t)
        ~(handler : _ request_handler) () =
      match Deque.dequeue_front deque with
      | Some (EReq (request, response_ivar) as e) -> (
          match%map handler.f ~state ~request with
          | RNext (state, resp) ->
              Ivar.fill response_ivar resp ;
              MNext state
          | RExit resp ->
              (* NOTE: for some reason OCaml can't infer this type here *)
              Ivar.fill response_ivar (Obj.magic resp) ;
              MExit
          | RUnprocessed ->
              Deque.enqueue_front deque e ;
              MUnprocessed )
      | None ->
          Deferred.return MUnprocessed
    in

    if actor.is_running then
      Deferred.Or_error.of_exn (RunningActorSpawned { name = actor.name })
    else (
      actor.is_running <- true ;
      let rec loop () =
        if not actor.is_running then Deferred.unit
        else
          let dispatchers =
            [ process_request ~state:actor.state ~deque:actor.request_inbox
                ~handler:actor.request_handler
            ; process_msg ~state:actor.state ~deque:actor.control_inbox
                ~handler:actor.control_handler
            ; process_msg ~state:actor.state ~deque:actor.data_inbox
                ~handler:actor.data_handler
            ]
          in
          let rec iter_dispatch = function
            | [] ->
                Deferred.return MUnprocessed
            | dispatcher :: dispatchers -> (
                match%bind dispatcher () with
                | MUnprocessed ->
                    iter_dispatch dispatchers
                | (MExit | MNext _) as processed ->
                    Deferred.return processed )
          in
          match%bind iter_dispatch dispatchers with
          | MNext state ->
              actor.state <- state ;
              loop ()
          | MExit ->
              actor.is_running <- false ;
              Deferred.unit
          | MUnprocessed ->
              let%bind () = Async.Scheduler.yield () in
              loop ()
      in

      let%bind.Deferred () = loop () in
      Deferred.Or_error.return () )
end

module Regular (DataMessage : sig
  type t

  val to_yojson : t -> Yojson.Safe.t
end) =
struct
  module Inner = WithRequest (DataMessage) (DummyRequest)
  include Inner

  let create = create ~request_handler:{ f = DummyRequest.handler }
end
