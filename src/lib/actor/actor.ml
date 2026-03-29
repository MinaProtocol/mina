open Async
open Core_kernel

module type S = sig
  type instance
  type state
  type handles

  val create :
       logger:Logger.t
    -> name:Yojson.Safe.t
    -> state:state
    -> instance * handles

  val terminate : instance:instance -> unit
  val spawn : instance:instance -> unit Deferred.t Or_error.t

  type ('msg, 'returns) channel_handle

  val send :
       instance:instance
    -> channel:('msg, 'returns) channel_handle
    -> message:'msg
    -> 'returns
end

(* Global channel_handle types, abstractly defined for the public API *)
(* Concrete constructors are internal to the Make functor *)
type ('msg, 'returns) channel_handle



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

module WithRequest (DataMessage : sig
  type t [@@deriving to_yojson]
end) (Request : sig
  type _ t
end) (Logic : sig
  type state

  type data_returns

  type data_overflew

  type control_msg

  val data_channel_type :
    (state, DataMessage.t, data_returns, data_overflew) channel_type

  val request_handler : state RequestHandler(Request).t

  val control_handler :
    state:state -> message:control_msg -> state msg_processed Deferred.t

  val data_handler :
    state:state -> message:DataMessage.t -> state msg_processed Deferred.t
end) : sig
  type instance

  val create :
    logger:Logger.t -> name:Yojson.Safe.t -> state:Logic.state -> instance

  val terminate : instance:instance -> unit

  val send_request :
    instance:instance -> request:'response Request.t -> 'response Deferred.t

  val send_control : instance:instance -> message:Logic.control_msg -> unit

  val send_data :
    instance:instance -> message:DataMessage.t -> Logic.data_returns

  val spawn : instance -> unit Deferred.t Or_error.t
end = struct
  exception
    ActorDataInboxOverflow of
      { name : Yojson.Safe.t; capacity : int; attempt_enqueing : DataMessage.t }

  type request_e = EReq : 'response Request.t * 'response Ivar.t -> request_e

  type instance =
    { logger : Logger.t
    ; name : Yojson.Safe.t
    ; request_inbox : request_e Deque.t
    ; control_inbox : Logic.control_msg Deque.t
    ; data_inbox : DataMessage.t Deque.t
    ; spawned : unit Ivar.t
    ; terminated : unit Ivar.t
    ; mutable work_available : unit Ivar.t
    ; mutable state : Logic.state
    }

  let create ~logger ~name ~state =
    { logger
    ; name
    ; request_inbox = Deque.create ()
    ; control_inbox = Deque.create ()
    ; data_inbox = Deque.create ()
    ; spawned = Ivar.create ()
    ; terminated = Ivar.create ()
    ; work_available = Ivar.create ()
    ; state
    }

  let terminate ~(instance : instance) =
    Ivar.fill_if_empty instance.terminated ()

  let send_request :
      type response.
      instance:instance -> request:response Request.t -> response Deferred.t =
   fun ~instance ~request ->
    let response = Ivar.create () in
    Deque.enqueue_back instance.request_inbox (EReq (request, response)) ;
    Ivar.fill_if_empty instance.work_available () ;
    Ivar.read response

  let send_control ~(instance : instance) ~message =
    Deque.enqueue_back instance.control_inbox message ;
    Ivar.fill_if_empty instance.work_available ()

  let send_data ~(instance : instance) ~(message : DataMessage.t) :
      Logic.data_returns =
    match Logic.data_channel_type with
    | Infinity ->
        Deque.enqueue_back instance.data_inbox message ;
        Ivar.fill_if_empty instance.work_available ()
    | With_capacity (`Capacity capacity, `Overflow Push_back) ->
        let open Deferred.Let_syntax in
        let rec wait_then_enqueue () =
          if Deque.length instance.data_inbox >= capacity then
            let%bind () = Scheduler.yield () in
            wait_then_enqueue ()
          else (
            Deque.enqueue_back instance.data_inbox message ;
            Ivar.fill_if_empty instance.work_available () ;
            Deferred.unit )
        in
        wait_then_enqueue ()
    | With_capacity (`Capacity capacity, `Overflow Throw) ->
        if Deque.length instance.data_inbox >= capacity then
          Or_error.of_exn
            (ActorDataInboxOverflow
               { name = instance.name; capacity; attempt_enqueing = message } )
        else (
          Deque.enqueue_back instance.data_inbox message ;
          Ivar.fill_if_empty instance.work_available () ;
          Ok () )
    | With_capacity (`Capacity capacity, `Overflow (Drop_head warns_or_not))
      -> (
        (* NOTE: always enqueue first to deal with capacity 0/negative *)
        Deque.enqueue_back instance.data_inbox message ;
        Ivar.fill_if_empty instance.work_available () ;
        if Deque.length instance.data_inbox > capacity then
          let dropped = Deque.dequeue_front_exn instance.data_inbox in
          match warns_or_not with
          | `Warns ->
              [%log' info instance.logger]
                "Actor $actor_id has data inbox capacity %d, dropping head \
                 message $message"
                capacity
                ~metadata:
                  [ ("actor_id", instance.name)
                  ; ("message", DataMessage.to_yojson dropped)
                  ; ("capacity", `Int capacity)
                  ]
          | `No_warns ->
              () )
    | With_capacity (`Capacity cap, `Overflow (Drop_and_call_head callback)) ->
        (* NOTE: always enqueue first to deal with capacity 0/negative *)
        Deque.enqueue_back instance.data_inbox message ;
        Ivar.fill_if_empty instance.work_available () ;
        if Deque.length instance.data_inbox > cap then
          let head = Deque.dequeue_front_exn instance.data_inbox in
          Some (callback instance.state head)
        else None

  let spawn (instance : instance) : unit Deferred.t Or_error.t =
    if Ivar.is_full instance.spawned then
      Or_error.errorf "Actor %s already spawned"
        (Yojson.Safe.to_string instance.name)
    else (
      Ivar.fill instance.spawned () ;
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
          ~(handler : Logic.state RequestHandler(Request).t) () =
        match Deque.dequeue_front deque with
        | Some (EReq (request, response_ivar) as e) -> (
            match%map handler.f ~state ~request with
            | RNext (state, resp) ->
                Ivar.fill response_ivar resp ;
                MNext state
            | RExit resp ->
                Ivar.fill response_ivar resp ;
                MExit
            | RUnprocessed ->
                Deque.enqueue_front deque e ;
                MUnprocessed )
        | None ->
            Deferred.return MUnprocessed
      in
      let rec loop () =
        if Ivar.is_full instance.terminated then Deferred.unit
        else
          let dispatchers =
            [ process_request ~state:instance.state
                ~deque:instance.request_inbox ~handler:Logic.request_handler
            ; process_msg ~state:instance.state ~deque:instance.control_inbox
                ~handler:Logic.control_handler
            ; process_msg ~state:instance.state ~deque:instance.data_inbox
                ~handler:Logic.data_handler
            ]
          in
          let rec iter_dispatch = function
            | [] ->
                Deferred.return None
            | dispatcher :: dispatchers -> (
                match%bind dispatcher () with
                | MUnprocessed ->
                    iter_dispatch dispatchers
                | (MExit | MNext _) as processed ->
                    Deferred.return (Some processed) )
          in
          match%bind iter_dispatch dispatchers with
          | Some (MNext state) ->
              instance.state <- state ;
              loop ()
          | Some MExit ->
              Ivar.fill_if_empty instance.terminated () ;
              Deferred.unit
          | Some MUnprocessed ->
              (* WARN: all handler decide not to handle the message, only thing
                 we could do is busy wait *)
              let%bind () = Scheduler.yield () in
              loop ()
          | None ->
              let%bind () = Ivar.read instance.work_available in
              instance.work_available <- Ivar.create () ;
              loop ()
      in
      Ok (loop ()) )
end

module type S = sig
  type instance

  type state

  type message

  type data_returns

  val create : logger:Logger.t -> name:Yojson.Safe.t -> state:state -> instance

  val spawn : instance -> unit Deferred.t Or_error.t

  val send_data : instance:instance -> message:message -> data_returns

  val terminate : instance:instance -> unit
end
