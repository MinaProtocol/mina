open Core_kernel
open Async

type 'state step = Stop | Next of 'state

module Message = struct
  type ('state, 'message, 'returns, 'behavior) overflow_behavior =
    | Report : (_, _, [ `Enqueued | `Failed ], [ `Report ]) overflow_behavior
    | Drop :
        [ `Head | `Tail ]
        -> (_, 'message, 'message option, [ `Drop ]) overflow_behavior
    | Push_back : (_, _, unit Deferred.t, [ `Push_back ]) overflow_behavior

  type ('state, 'message, 'returns, 'behavior) channel_type =
    | Unbounded : (_, _, unit, [ `Unbounded ]) channel_type
    | Bounded :
        [ `Capacity of int ]
        * [ `On_overflow of
            ('state, 'message, 'returns, 'behavior) overflow_behavior ]
        -> ('state, 'message, 'returns, 'behavior) channel_type

  type ('state, 'message, 'returns, 'behavior) channel =
    { type_ : ('state, 'message, 'returns, 'behavior) channel_type
    ; handler : state:'state -> message:'message -> 'state step Deferred.t
    ; message_to_yojson : 'message -> Yojson.Safe.t
    ; inbox : 'message Deque.t
    ; name : Yojson.Safe.t
    }

  let send (type message returns behavior)
      ~(channel : (_, message, returns, behavior) channel) ~(message : message)
      ~work_available : returns =
    match channel.type_ with
    | Unbounded ->
        Deque.enqueue_back channel.inbox message ;
        Ivar.fill_if_empty work_available ()
    | Bounded (`Capacity capacity, `On_overflow Push_back) ->
        let rec wait_then_enqueue () =
          if Deque.length channel.inbox >= capacity then
            let%bind () = Scheduler.yield () in
            wait_then_enqueue ()
          else (
            Deque.enqueue_back channel.inbox message ;
            Ivar.fill_if_empty work_available () ;
            Deferred.unit )
        in
        wait_then_enqueue ()
    | Bounded (`Capacity capacity, `On_overflow Report) ->
        if Deque.length channel.inbox >= capacity then `Failed
        else (
          Deque.enqueue_back channel.inbox message ;
          Ivar.fill_if_empty work_available () ;
          `Enqueued )
    | Bounded (`Capacity capacity, `On_overflow (Drop head_or_tail)) ->
        assert (capacity > 0) ;
        let dequeued =
          if Deque.length channel.inbox >= capacity then
            match head_or_tail with
            | `Head ->
                Deque.dequeue_front channel.inbox
            | `Tail ->
                Deque.dequeue_back channel.inbox
          else None
        in
        Deque.enqueue_back channel.inbox message ;
        Ivar.fill_if_empty work_available () ;
        dequeued
end

module Request = struct
  type ('state, 'response, 'error, 'behavior) channel_type =
    | Unbounded : (_, 'response, [ `Stopped ], [ `Unbounded ]) channel_type
    | BoundedReport :
        [ `Capacity of int ]
        -> ( _
           , 'response
           , [ `Stopped | `Dropped ]
           , [ `BoundedReport ] )
           channel_type

  type ('state, 'request, 'response, 'error, 'behavior) channel =
    { type_ : ('state, 'response, 'error, 'behavior) channel_type
    ; handler :
           state:'state
        -> request:'request
        -> ('state step * ('response, 'error) result) Deferred.t
    ; request_to_yojson : 'request -> Yojson.Safe.t
    ; inbox : ('request * ('response, 'error) result Ivar.t) Deque.t
    ; name : Yojson.Safe.t
    ; stopped_returns : 'error
          (* This is so I don't need Obj.magic when filling every request with
             `Stopped when the actor stops*)
    }

  let send (type request response error behavior)
      ~(channel : (_, request, response, error, behavior) channel)
      ~(request : request) ~work_available : (response, error) Deferred.Result.t
      =
    match channel.type_ with
    | Unbounded ->
        let response = Ivar.create () in
        Deque.enqueue_back channel.inbox (request, response) ;
        Ivar.fill_if_empty work_available () ;
        Ivar.read response
    | BoundedReport (`Capacity capacity) ->
        if Deque.length channel.inbox >= capacity then
          Deferred.return (Error `Dropped)
        else
          let response = Ivar.create () in
          Deque.enqueue_back channel.inbox (request, response) ;
          Ivar.fill_if_empty work_available () ;
          Ivar.read response
end

module Make (Inputs : sig
  type state
end) =
struct
  open Inputs

  type any_channel =
    | MessageChannel : (state, _, _, _) Message.channel -> any_channel
    | RequestChannel : (state, _, _, _, _) Request.channel -> any_channel

  type instance =
    { logger : Logger.t
    ; name : Yojson.Safe.t
    ; channels : any_channel ref Queue.t
    ; channel_selector : (int, any_channel ref) Hashtbl.t
    ; spawned : unit Ivar.t
    ; stopped : unit Ivar.t
    ; mutable work_available : unit Ivar.t
    ; mutable state : state
    ; next_channel_id : int ref
    }

  type (_, 'kind) handle = Handle : (instance * int) -> (_, _) handle

  let create ~logger ~name ~state =
    { logger
    ; name
    ; channels = Queue.create ()
    ; channel_selector = Int.Table.create ()
    ; spawned = Ivar.create ()
    ; stopped = Ivar.create ()
    ; work_available = Ivar.create ()
    ; state
    ; next_channel_id = ref 0
    }

  let bind_message_channel (type message returns behavior)
      ~(instance : instance)
      ~(channel : (state, message, returns, behavior) Message.channel) :
      ((state, message, returns, behavior) Message.channel, [ `Message ]) handle
      =
    let channel_ref = ref (MessageChannel channel) in
    let handle_id = !(instance.next_channel_id) in
    incr instance.next_channel_id ;
    let handle = Handle (instance, handle_id) in
    Queue.enqueue instance.channels channel_ref ;
    Int.Table.set instance.channel_selector ~key:handle_id ~data:channel_ref ;
    handle

  let bind_request_channel (type request response returns behavior)
      ~(instance : instance)
      ~(channel : (state, request, response, returns, behavior) Request.channel)
      :
      ( (state, request, response, returns, behavior) Request.channel
      , [ `Request ] )
      handle =
    let channel_ref = ref (RequestChannel channel) in
    let handle_id = !(instance.next_channel_id) in
    incr instance.next_channel_id ;
    let handle = Handle (instance, handle_id) in
    Queue.enqueue instance.channels channel_ref ;
    Int.Table.set instance.channel_selector ~key:handle_id ~data:channel_ref ;
    handle

  let send (type message returns behavior)
      ~(handle :
         ( (state, message, returns, behavior) Message.channel
         , [ `Message ] )
         handle ) ~(message : message) =
    let (Handle (instance, handle_id)) = handle in
    let channel_ref : any_channel ref =
      Int.Table.find_exn instance.channel_selector handle_id
    in
    match !channel_ref with
    | MessageChannel channel ->
        let channel : (state, message, returns, behavior) Message.channel =
          Obj.magic channel
        in
        Message.send ~channel ~message ~work_available:instance.work_available
    | _ ->
        failwith "Unreahable: typing error in channel selector"

  let request (type request response returns behavior)
      ~(handle :
         ( (state, request, response, returns, behavior) Request.channel
         , [ `Request ] )
         handle ) ~(request : request) =
    let (Handle (instance, handle_id)) = handle in
    let channel_ref : any_channel ref =
      Int.Table.find_exn instance.channel_selector handle_id
    in
    match !channel_ref with
    | RequestChannel channel ->
        let channel :
            (state, request, response, returns, behavior) Request.channel =
          Obj.magic channel
        in
        Request.send ~channel ~request ~work_available:instance.work_available
    | _ ->
        failwith "Unreahable: typing error in channel selector"

  let stop ~(instance : instance) = Ivar.fill_if_empty instance.stopped ()

  exception RepeatedSpawningActor of instance

  let handle_channel ~state = function
    | MessageChannel chan -> (
        match Deque.dequeue_front chan.inbox with
        | None ->
            Deferred.return None
        | Some message ->
            let%map step = chan.handler ~state ~message in
            Some step )
    | RequestChannel chan -> (
        match Deque.dequeue_front chan.inbox with
        | None ->
            Deferred.return None
        | Some (request, response_ivar) ->
            let%map step, response = chan.handler ~state ~request in
            Ivar.fill response_ivar (Obj.magic (`Ok response)) ;
            Some step )

  let step instance =
    let step_result =
      Queue.fold instance.channels ~init:(Deferred.return None)
        ~f:(fun acc chan ->
          match%bind acc with
          | None ->
              handle_channel ~state:instance.state !chan
          | step ->
              Deferred.return step )
    in
    match%bind step_result with
    | Some (Next state) ->
        instance.state <- state ;
        Deferred.return (`Repeat instance)
    | Some Stop ->
        Ivar.fill_if_empty instance.stopped () ;
        Deferred.return (`Finished instance.state)
    | None ->
        let%map () = Ivar.read instance.work_available in
        instance.work_available <- Ivar.create () ;
        `Repeat instance

  let spawn (instance : instance) : state Deferred.t =
    if Ivar.is_full instance.spawned then raise (RepeatedSpawningActor instance) ;
    Ivar.fill instance.spawned () ;
    let%map final_state = Deferred.repeat_until_finished instance step in
    Queue.iter instance.channels ~f:(fun chan ->
        match !chan with
        | MessageChannel _ ->
            ()
        | RequestChannel chan ->
            Deque.iter chan.inbox ~f:(fun (_, response_ivar) ->
                Ivar.fill response_ivar (Error chan.stopped_returns) ) ) ;
    final_state
end
