open Async
open Core

module Make (DataMessage : sig
  type t

  val to_yojson : t -> Yojson.Safe.t
end) =
struct
  exception
    ActorDataInboxOverflow of
      { name : string; capacity : int; attempt_enqueing : DataMessage.t }

  exception RunningActorSpawned of { name : string }

  type (_, _) overflow_behavior =
    | Throw : (unit Or_error.t, [ `Throw ]) overflow_behavior
    | Drop_head :
        [ `Warns | `No_warns ]
        -> (unit, [ `Drop_head ]) overflow_behavior
    | Call_head :
        (DataMessage.t -> 'returns)
        -> ('returns option, [ `Call_head ]) overflow_behavior
    | Push_back : (unit Deferred.t, [ `Push_back ]) overflow_behavior

  type (_, _) channel_type =
    | Infinity : (unit, [ `Infinity ]) channel_type
    | With_capacity :
        [ `Capacity of int ]
        * [ `Overflow of ('returns, 'behavior) overflow_behavior ]
        -> ('returns, 'behavior) channel_type

  type 'state or_exit = Next of 'state | Exit

  type ('data_returns, 'data_overflew, 'control_msg, 'state) t =
    { name : string
    ; control_inbox : 'control_msg Queue.t
    ; data_inbox : DataMessage.t Queue.t
    ; data_channel_type : ('data_returns, 'data_overflew) channel_type
    ; data_handler :
        state:'state -> message:DataMessage.t -> 'state or_exit Deferred.t
    ; control_handler :
        state:'state -> message:'control_msg -> 'state or_exit Deferred.t
    ; logger : Logger.t
    ; mutable is_running : bool
    ; mutable state : 'state
    }

  let create ~name ~data_channel_type ~data_handler ~control_handler ~logger
      ~state =
    { name
    ; control_inbox = Queue.create ()
    ; data_inbox = Queue.create ()
    ; data_channel_type
    ; data_handler
    ; control_handler
    ; logger
    ; is_running = false
    ; state
    }

  let terminate ~(actor : _ t) = actor.is_running <- false

  let send_control ~(actor : _ t) ~message =
    Queue.enqueue actor.control_inbox message

  let send_data :
      type data_returns data_overflew.
         actor:(data_returns, data_overflew, _, _) t
      -> message:DataMessage.t
      -> data_returns =
   fun ~actor ~message ->
    match actor.data_channel_type with
    | Infinity ->
        Queue.enqueue actor.data_inbox message
    | With_capacity (`Capacity capacity, `Overflow Push_back) ->
        let open Deferred.Let_syntax in
        let rec wait_then_enqueue () =
          if Queue.length actor.data_inbox >= capacity then
            let%bind () = Async.Scheduler.yield () in
            wait_then_enqueue ()
          else (
            Queue.enqueue actor.data_inbox message ;
            Deferred.return () )
        in
        wait_then_enqueue ()
    | With_capacity (`Capacity capacity, `Overflow Throw) ->
        if Queue.length actor.data_inbox >= capacity then
          Or_error.of_exn
            (ActorDataInboxOverflow
               { name = actor.name; capacity; attempt_enqueing = message } )
        else Ok ()
    | With_capacity (`Capacity capacity, `Overflow (Drop_head warns_or_not))
      -> (
        (* NOTE: always enqueue first to deal with capacity 0/negative *)
        Queue.enqueue actor.data_inbox message ;
        if Queue.length actor.data_inbox > capacity then
          let dropped = Queue.dequeue_exn actor.data_inbox in
          match warns_or_not with
          | `Warns ->
              let logger = actor.logger in
              [%log info]
                "Actor %s has data inbox capacity %d, dropping head message \
                 $message"
                actor.name capacity
                ~metadata:[ ("message", DataMessage.to_yojson dropped) ]
          | `No_warns ->
              () )
    | With_capacity (`Capacity cap, `Overflow (Call_head callback)) ->
        (* NOTE: always enqueue first to deal with capacity 0/negative *)
        Queue.enqueue actor.data_inbox message ;

        if Queue.length actor.data_inbox > cap then
          let head = Queue.dequeue_exn actor.data_inbox in
          Some (callback head)
        else None

  let spawn (actor : _ t) : unit Deferred.Or_error.t =
    if actor.is_running then
      Deferred.Or_error.of_exn (RunningActorSpawned { name = actor.name })
    else (
      actor.is_running <- true ;
      let rec loop () =
        if not actor.is_running then Deferred.unit
        else
          match Queue.dequeue actor.control_inbox with
          | Some control_msg -> (
              let%bind new_state =
                actor.control_handler ~state:actor.state ~message:control_msg
              in
              match new_state with
              | Next new_state ->
                  actor.state <- new_state ;
                  loop ()
              | Exit ->
                  Deferred.unit )
          | None -> (
              match Queue.dequeue actor.data_inbox with
              | Some data_msg -> (
                  let%bind new_state =
                    actor.data_handler ~state:actor.state ~message:data_msg
                  in
                  match new_state with
                  | Next new_state ->
                      actor.state <- new_state ;
                      loop ()
                  | Exit ->
                      Deferred.unit )
              | None ->
                  let%bind () = Async.Scheduler.yield () in
                  loop () )
      in
      let%bind.Deferred () = loop () in
      Deferred.Or_error.return () )
end
